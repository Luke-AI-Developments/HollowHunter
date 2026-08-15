package com.hollowhunter.gpshealthbridge

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * Throwaway spike: bridges FusedLocationProvider (GPS) and Health Connect
 * (steps/workouts) into GDScript. Foreground-only -- no background
 * location or health polling. Everything here is read-only.
 *
 * Written against the documented GodotPlugin v2 API (@UsedByGodot,
 * getPluginSignals()/emitSignal(), the onMain*() lifecycle overrides) but
 * NOT compiled -- no Android toolchain on this machine yet. Two spots most
 * likely to need adjustment once you actually build this:
 *   - `activity` (inherited from GodotPlugin): confirm the exact accessor
 *     name/nullability against your installed Godot version's plugin API.
 *   - onMainCreate()'s cast to ComponentActivity: confirm Godot's hosting
 *     activity extends it in your engine version (it has for a while, but
 *     verify against the version you install).
 */
class GpsHealthBridgePlugin(godot: Godot) : GodotPlugin(godot) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val fusedLocationClient: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(activity!!)
    }
    private var locationCallback: LocationCallback? = null

    private var healthConnectClient: HealthConnectClient? = null
    private var healthPermissionLauncher: ActivityResultLauncher<Set<String>>? = null

    private val healthPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class)
    )

    override fun getPluginName(): String = "GpsHealthBridge"

    // Checkpoint 2: hello-world round trip, proves the bridge + Gradle/AAR
    // build before GPS/Health Connect are exercised in checkpoints 3-4.
    @UsedByGodot
    fun helloWorld(): String = "Hello from Kotlin!"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("location_permission_result", Boolean::class.javaObjectType),
        SignalInfo(
            "location_update",
            Double::class.javaObjectType,
            Double::class.javaObjectType,
            Float::class.javaObjectType,
            Long::class.javaObjectType
        ),
        SignalInfo("health_connect_available", Boolean::class.javaObjectType),
        SignalInfo("health_permission_result", Boolean::class.javaObjectType),
        SignalInfo("steps_result", Int::class.javaObjectType),
        SignalInfo("workouts_result", String::class.java)
    )

    override fun onMainCreate(activity: android.app.Activity): android.view.View? {
        // Health Connect's permission dialog is a normal ActivityResultContract,
        // not a runtime permission -- the launcher must be registered before
        // the hosting activity reaches STARTED, so this is done here rather
        // than lazily inside requestHealthPermissions().
        // VERIFY: Godot's hosting activity extends ComponentActivity as of the
        // engine version you're building against; if this cast fails, register
        // the launcher wherever your Godot version exposes activity lifecycle
        // hooks early enough instead.
        (activity as? ComponentActivity)?.let { componentActivity ->
            healthPermissionLauncher = componentActivity.registerForActivityResult(
                PermissionController.createRequestPermissionResultContract()
            ) { granted ->
                emitSignal("health_permission_result", granted.containsAll(
                    healthPermissions.map {
                        // HealthPermission objects stringify to their permission string.
                        it.toString()
                    }
                ))
            }
        }
        return super.onMainCreate(activity)
    }

    override fun onMainDestroy() {
        stopLocationUpdates()
        scope.cancel()
        super.onMainDestroy()
    }

    // ---- GPS (FusedLocationProviderClient) ----------------------------

    @UsedByGodot
    fun requestLocationPermission() {
        val act = activity ?: return
        val granted = ContextCompat.checkSelfPermission(
            act, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            emitSignal("location_permission_result", true)
            return
        }
        act.requestPermissions(
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            LOCATION_PERMISSION_REQUEST_CODE
        )
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            emitSignal("location_permission_result", granted)
        }
    }

    @UsedByGodot
    fun startLocationUpdates() {
        val act = activity ?: return
        if (ContextCompat.checkSelfPermission(act, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2000L)
            .setMinUpdateIntervalMillis(1000L)
            .build()
        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return
                emitSignal(
                    "location_update",
                    loc.latitude,
                    loc.longitude,
                    loc.accuracy,
                    loc.time
                )
            }
        }
        locationCallback = callback
        fusedLocationClient.requestLocationUpdates(request, callback, act.mainLooper)
    }

    @UsedByGodot
    fun stopLocationUpdates() {
        locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
        locationCallback = null
    }

    // ---- Health Connect -------------------------------------------------

    @UsedByGodot
    fun checkHealthConnectAvailable() {
        val act = activity ?: return
        val status = HealthConnectClient.getSdkStatus(act)
        val available = status == HealthConnectClient.SDK_AVAILABLE
        if (available) {
            healthConnectClient = HealthConnectClient.getOrCreate(act)
        }
        emitSignal("health_connect_available", available)
    }

    @UsedByGodot
    fun requestHealthPermissions() {
        val client = healthConnectClient ?: run {
            emitSignal("health_permission_result", false)
            return
        }
        scope.launch {
            val granted = client.permissionController.getGrantedPermissions()
            if (granted.containsAll(healthPermissions)) {
                emitSignal("health_permission_result", true)
            } else {
                healthPermissionLauncher?.launch(healthPermissions.map { it.toString() }.toSet())
                    ?: emitSignal("health_permission_result", false)
            }
        }
    }

    @UsedByGodot
    fun readTodaySteps() {
        val client = healthConnectClient ?: run {
            emitSignal("steps_result", 0)
            return
        }
        scope.launch {
            try {
                val startOfDay = Instant.now().minusSeconds(24 * 60 * 60)
                val response = client.readRecords(
                    ReadRecordsRequest(
                        StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startOfDay, Instant.now())
                    )
                )
                val total = response.records.sumOf { it.count }
                emitSignal("steps_result", total.toInt())
            } catch (e: Exception) {
                // Health Connect can hand back a malformed record (e.g. a
                // 0-count StepsRecord, which the SDK's own constructor
                // rejects) and throw mid-read instead of just skipping it.
                // Degrade to 0 steps rather than crashing the app.
                Log.w(TAG, "readTodaySteps failed, reporting 0", e)
                emitSignal("steps_result", 0)
            }
        }
    }

    @UsedByGodot
    fun readRecentWorkouts(hours: Int) {
        val client = healthConnectClient ?: run {
            emitSignal("workouts_result", "[]")
            return
        }
        scope.launch {
            try {
                val start = Instant.now().minusSeconds(hours.toLong() * 60 * 60)
                val response = client.readRecords(
                    ReadRecordsRequest(
                        ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, Instant.now())
                    )
                )
                val json = JSONArray()
                response.records.forEach { record ->
                    json.put(
                        JSONObject().apply {
                            put("title", record.title ?: "")
                            put("exercise_type", record.exerciseType)
                            put("start_time", record.startTime.toString())
                            put("end_time", record.endTime.toString())
                        }
                    )
                }
                emitSignal("workouts_result", json.toString())
            } catch (e: Exception) {
                // Same malformed-record defense as readTodaySteps().
                Log.w(TAG, "readRecentWorkouts failed, reporting none", e)
                emitSignal("workouts_result", "[]")
            }
        }
    }

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 4128
        private const val TAG = "GpsHealthBridge"
    }
}
