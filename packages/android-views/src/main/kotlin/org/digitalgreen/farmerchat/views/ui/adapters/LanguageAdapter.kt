package org.digitalgreen.farmerchat.views.ui.adapters

import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.ItemLanguageCardBinding
import org.digitalgreen.farmerchat.views.network.LanguageResponse

/**
 * RecyclerView adapter for language selection cards.
 *
 * Displays language native name, English name, and code. Highlights the currently
 * selected language. Used in both onboarding and profile screens.
 *
 * All bind operations are wrapped in try-catch — the SDK must never crash the host app.
 *
 * @param selectedCode Initially selected language code.
 * @param onLanguageSelected Callback when a language card is tapped.
 */
internal class LanguageAdapter(
    private var selectedCode: String,
    private val onLanguageSelected: (String) -> Unit,
) : ListAdapter<LanguageResponse, LanguageAdapter.LanguageViewHolder>(LanguageDiffCallback()) {

    private companion object {
        const val TAG = "FC.LanguageAdapter"
    }

    fun setSelectedCode(code: String) {
        try {
            val oldCode = selectedCode
            selectedCode = code
            // Refresh items that changed selection state
            currentList.forEachIndexed { index, lang ->
                if (lang.code == oldCode || lang.code == code) {
                    notifyItemChanged(index)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "setSelectedCode failed", e)
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): LanguageViewHolder {
        val binding = ItemLanguageCardBinding.inflate(
            LayoutInflater.from(parent.context), parent, false,
        )
        return LanguageViewHolder(binding)
    }

    override fun onBindViewHolder(holder: LanguageViewHolder, position: Int) {
        try {
            holder.bind(getItem(position))
        } catch (e: Exception) {
            Log.w(TAG, "onBindViewHolder failed at position $position", e)
        }
    }

    inner class LanguageViewHolder(
        private val binding: ItemLanguageCardBinding,
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(language: LanguageResponse) {
            try {
                binding.textNativeName.text = language.nativeName
                binding.textName.text = language.name
                binding.textCode.text = language.code.uppercase()

                val isSelected = language.code == selectedCode
                val bgColor = if (isSelected) {
                    ContextCompat.getColor(binding.root.context, R.color.fc_selected_language_bg)
                } else {
                    ContextCompat.getColor(binding.root.context, R.color.fc_card_background)
                }
                binding.cardLanguage.setCardBackgroundColor(bgColor)

                binding.root.setOnClickListener {
                    try {
                        onLanguageSelected(language.code)
                    } catch (e: Exception) {
                        Log.w(TAG, "Language card click failed", e)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "LanguageViewHolder.bind failed", e)
            }
        }
    }

    private class LanguageDiffCallback : DiffUtil.ItemCallback<LanguageResponse>() {
        override fun areItemsTheSame(
            oldItem: LanguageResponse,
            newItem: LanguageResponse,
        ): Boolean = oldItem.code == newItem.code

        override fun areContentsTheSame(
            oldItem: LanguageResponse,
            newItem: LanguageResponse,
        ): Boolean = oldItem == newItem
    }
}
