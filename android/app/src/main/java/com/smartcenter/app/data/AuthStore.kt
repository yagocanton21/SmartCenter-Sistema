package com.smartcenter.app.data

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.UUID

class AuthStore(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("smartcenter_auth", Context.MODE_PRIVATE)
    private val gson = Gson()

    private val _currentUser = MutableStateFlow<User?>(null)
    val currentUser = _currentUser.asStateFlow()

    private val _serverUrl = MutableStateFlow(prefs.getString("server_url", "http://10.0.2.2:3000") ?: "http://10.0.2.2:3000")
    val serverUrl = _serverUrl.asStateFlow()

    private var csrfToken: String = prefs.getString("csrf_token", "") ?: ""
    private val cookieJar = PersistentCookieJar(prefs)

    private val client = OkHttpClient.Builder()
        .cookieJar(cookieJar)
        .build()

    init {
        val userJson = prefs.getString("saved_user", null)
        if (!userJson.isNullOrEmpty()) {
            try {
                _currentUser.value = gson.fromJson(userJson, User::class.java)
            } catch (_: Exception) {}
        }
    }

    fun setServerUrl(url: String) {
        val clean = url.trimEnd('/')
        if (clean != _serverUrl.value) {
            _serverUrl.value = clean
            prefs.edit().putString("server_url", clean).apply()
            cookieJar.clear()
            prefs.edit().remove("saved_user").remove("csrf_token").apply()
            _currentUser.value = null
        }
    }

    suspend fun login(loginStr: String, passStr: String): Result<User> = withContext(Dispatchers.IO) {
        try {
            val json = gson.toJson(mapOf("login" to loginStr, "password" to passStr))
            val req = Request.Builder()
                .url("${_serverUrl.value}/api/auth/login")
                .post(json.toRequestBody("application/json".toMediaType()))
                .build()

            val resp = client.newCall(req).execute()
            val body = resp.body?.string() ?: ""

            if (!resp.isSuccessful) {
                val mapType = object : TypeToken<Map<String, Any?>>() {}.type
                val errMap = try { gson.fromJson<Map<String, Any?>>(body, mapType) } catch (_: Exception) { null }
                val msg = errMap?.get("error") as? String ?: "Credenciais inválidas (${resp.code})"
                return@withContext Result.failure(Exception(msg))
            }

            val mapType = object : TypeToken<Map<String, Any?>>() {}.type
            val resMap: Map<String, Any?> = gson.fromJson(body, mapType)

            csrfToken = resMap["csrf"] as? String ?: ""
            prefs.edit().putString("csrf_token", csrfToken).apply()

            val userObj = resMap["user"] ?: return@withContext Result.failure(Exception("Dados de usuário não recebidos"))
            val userJson = gson.toJson(userObj)
            val user = gson.fromJson(userJson, User::class.java)

            prefs.edit().putString("saved_user", userJson).apply()
            _currentUser.value = user
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun logout() = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url("${_serverUrl.value}/api/auth/logout")
                .post("{}".toRequestBody("application/json".toMediaType()))
                .build()
            client.newCall(req).execute()
        } catch (_: Exception) {}
        cookieJar.clear()
        prefs.edit().remove("saved_user").remove("csrf_token").apply()
        _currentUser.value = null
    }

    suspend fun fetchDB(): Result<Map<String, Any?>> = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url("${_serverUrl.value}/api/db")
                .get()
                .build()

            val resp = client.newCall(req).execute()
            if (resp.code == 401) {
                withContext(Dispatchers.Main) {
                    cookieJar.clear()
                    prefs.edit().remove("saved_user").remove("csrf_token").apply()
                    _currentUser.value = null
                }
                return@withContext Result.failure(Exception("Sessão expirada. Faça login novamente."))
            }

            if (!resp.isSuccessful) {
                return@withContext Result.failure(Exception("Erro na resposta: ${resp.code}"))
            }

            val body = resp.body?.string() ?: ""
            val mapType = object : TypeToken<Map<String, Any?>>() {}.type
            val envelope: Map<String, Any?> = gson.fromJson(body, mapType)
            val db = (envelope["db"] as? Map<String, Any?>) ?: envelope
            Result.success(db)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun saveOrder(orderPayload: Map<String, Any?>): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val json = gson.toJson(orderPayload)
            val req = Request.Builder()
                .url("${_serverUrl.value}/api/os")
                .addHeader("X-CSRF-Token", csrfToken)
                .addHeader("Idempotency-Key", UUID.randomUUID().toString())
                .post(json.toRequestBody("application/json".toMediaType()))
                .build()

            val resp = client.newCall(req).execute()
            val body = resp.body?.string() ?: ""
            if (!resp.isSuccessful) {
                val mapType = object : TypeToken<Map<String, Any?>>() {}.type
                val errMap = try { gson.fromJson<Map<String, Any?>>(body, mapType) } catch (_: Exception) { null }
                val msg = errMap?.get("error") as? String ?: "Falha ao salvar OS (${resp.code})"
                return@withContext Result.failure(Exception(msg))
            }

            Result.success(true)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun deleteRecord(entity: String, id: String, before: Map<String, Any?>): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val change = mapOf(
                "entity" to entity,
                "id" to id,
                "before" to before,
                "after" to null
            )
            val payload = gson.toJson(mapOf("changes" to listOf(change)))

            val req = Request.Builder()
                .url("${_serverUrl.value}/api/changes")
                .addHeader("X-CSRF-Token", csrfToken)
                .addHeader("X-Idempotency-Key", UUID.randomUUID().toString())
                .post(payload.toRequestBody("application/json".toMediaType()))
                .build()

            val resp = client.newCall(req).execute()
            if (resp.isSuccessful) Result.success(true)
            else Result.failure(Exception("Erro ao excluir: ${resp.code}"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun cancelSale(saleId: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url("${_serverUrl.value}/api/vendas/$saleId/cancelar")
                .addHeader("X-CSRF-Token", csrfToken)
                .post("{}".toRequestBody("application/json".toMediaType()))
                .build()

            val resp = client.newCall(req).execute()
            if (resp.isSuccessful) Result.success(true)
            else Result.failure(Exception("Erro ao cancelar: ${resp.code}"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun changeRecordStatus(entity: String, id: String, before: Map<String, Any?>, newStatus: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val after = before.toMutableMap()
            after["status"] = newStatus

            val change = mapOf(
                "entity" to entity,
                "id" to id,
                "before" to before,
                "after" to after
            )
            val payload = gson.toJson(mapOf("changes" to listOf(change)))

            val req = Request.Builder()
                .url("${_serverUrl.value}/api/changes")
                .addHeader("X-CSRF-Token", csrfToken)
                .addHeader("X-Idempotency-Key", UUID.randomUUID().toString())
                .post(payload.toRequestBody("application/json".toMediaType()))
                .build()

            val resp = client.newCall(req).execute()
            if (resp.isSuccessful) Result.success(true)
            else Result.failure(Exception("Erro ao atualizar: ${resp.code}"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

class PersistentCookieJar(private val prefs: SharedPreferences) : CookieJar {
    private val cookies = mutableListOf<Cookie>()

    init {
        val saved = prefs.getStringSet("saved_cookies", emptySet()) ?: emptySet()
        for (item in saved) {
            val parts = item.split(":::", limit = 2)
            if (parts.size == 2) {
                val httpUrl = parts[0].toHttpUrlOrNull()
                if (httpUrl != null) {
                    val cookie = Cookie.parse(httpUrl, parts[1])
                    if (cookie != null && !cookie.hasExpired()) {
                        cookies.add(cookie)
                    }
                }
            }
        }
    }

    @Synchronized
    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        this.cookies.removeAll { old -> cookies.any { it.name == old.name } }
        this.cookies.addAll(cookies)
        persist()
    }

    @Synchronized
    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        return cookies.filter { !it.hasExpired() }
    }

    @Synchronized
    fun clear() {
        cookies.clear()
        prefs.edit().remove("saved_cookies").apply()
    }

    private fun persist() {
        val set = cookies.filter { !it.hasExpired() }.map {
            val scheme = if (it.secure) "https" else "http"
            "$scheme://${it.domain}/:::${it}"
        }.toSet()
        prefs.edit().putStringSet("saved_cookies", set).apply()
    }

    private fun Cookie.hasExpired(): Boolean {
        return expiresAt < System.currentTimeMillis()
    }
}
