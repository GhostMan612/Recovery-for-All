// android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasBridgeFactory.kt
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall.atlas

import android.content.Context

/**
 * Deliberately separate from [AtlasChannelAdapter].
 *
 * The factory is the only class that names [AtlasNativeBridge], so loading the
 * adapter on API 24/25 cannot pull in Atlas SDK classes through verification.
 * It is called only after the `SDK_INT >= 26` check.
 */
internal object AtlasBridgeFactory {
    fun create(context: Context): AtlasChannelAdapter.Delegate =
        AtlasNativeBridge(context).also { it.initAsync() }
}
