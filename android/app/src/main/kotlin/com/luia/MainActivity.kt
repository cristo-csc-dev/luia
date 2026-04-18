package com.luia

import android.content.Intent
import android.os.Bundle
import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    companion object {
        var formerActivity: com.luia.MainActivity? = null
    }

    private val CHANNEL = "com.luia/channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate")
        Log.d("MainActivity", intent.toString())
        if(formerActivity != null) {
            formerActivity?.finish()
        }
        formerActivity = this
    }

    override fun onResume() {
        super.onResume()
        handleIntent(intent)
    }

    private fun handleIntent(intentParam: Intent) {
        getIntentExtras(intentParam)
        printIntentStack(intentParam)
        // Verificar si el Intent contiene datos
        if ((intentParam?.action == Intent.ACTION_VIEW || intentParam.action ==Intent.ACTION_SEND) && intentParam.type != null) {
            when {
                intentParam.type?.contains("x-vcard") == true -> {
                    // Si el Intent es de tipo vCard, procesar el archivo
                    handleVCardIntent(intentParam)
                }
                else -> {
                    handleExternalLink(intentParam)
                }
            }
        }
    }

    private fun handleExternalLink(intentParam: Intent) {
        val intentExtraContent = getIntentExtras(intentParam)
        Log.d("intentExtraContent: ", intentExtraContent.toString())
        val intentAsJson = JSONObject(intentExtraContent).toString()
        Log.d("intentAsJson: ", intentAsJson)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            {}
            MethodChannel(messenger, CHANNEL).invokeMethod(
                "onSharedText",
                intentAsJson
            )
        }
    }

    private fun handleVCardIntent(intent: Intent) {
        getIntentExtras(intent)

    }

    private fun getIntentExtras(intentParam: Intent):Map<String, Any?> {
        val extras: Bundle? = intent.extras // 1. Obtener el Bundle de extras
        val result: HashMap<String, Any?> = HashMap<String, Any?>()
        if (extras != null) {
            val tag = "INTENT_EXTRAS" // Etiqueta para filtrar fácilmente
            Log.d(tag, "--- INICIO DE EXTRAS ---")
            for (key in extras.keySet()) {
                val value = extras.get(key) // Obtener el valor asociado a la clave
                Log.d(tag, String.format("Clave: %s | Valor: %s | Tipo: %s",
                    key, value.toString(), value?.javaClass?.simpleName))
                result[key] = value.toString().replace("\n", " ").trim()
            }
            Log.d(tag, "--- FIN DE EXTRAS ---")
        } else {
            Log.d("INTENT_EXTRAS", "No se encontraron extras en el Intent.")
        }
        return result
    }

    fun printIntentStack(intentParm: Intent) {
        val clipDataItem = intent.clipData?.getItemAt(0)
        val vcardUri = clipDataItem?.uri
        if (vcardUri != null) {
            try {
                // Abre el InputStream para leer el contenido de la URI
                val inputStream: InputStream? = contentResolver.openInputStream(vcardUri)
                if (inputStream != null) {
                    val reader = BufferedReader(InputStreamReader(inputStream))
                    // Aquí puedes leer y parsear el contenido vCard
                    val vcardContent = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        vcardContent.append(line).append("\n")
                    }
                    reader.close()
                    inputStream.close()
                    val tag = "INTENT_URI" // Etiqueta para filtrar fácilmente
                    Log.d(tag, "--- INICIO DE URI ---")
                    Log.d("vcard", vcardContent.toString());
                    Log.d(tag, "--- FIN DE URI ---")
                    // Ahora puedes usar 'vcardContent' para extraer la información del contacto
                    // ...
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}