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
import org.digitalgreen.farmerchat.views.network.SupportedLanguage

/**
 * RecyclerView adapter for language selection cards.
 *
 * Displays language display name, English name, and code. Highlights the currently
 * selected language. Used in both onboarding and profile screens.
 */
internal class LanguageAdapter(
    private var selectedCode: String,
    private val onLanguageSelected: (SupportedLanguage) -> Unit,
) : ListAdapter<SupportedLanguage, LanguageAdapter.LanguageViewHolder>(LanguageDiffCallback()) {

    private companion object {
        const val TAG = "FC.LanguageAdapter"
    }

    fun setSelectedCode(code: String) {
        try {
            val oldCode = selectedCode
            selectedCode = code
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

        fun bind(language: SupportedLanguage) {
            try {
                binding.textNativeName.text = language.displayName.takeIf { it.isNotEmpty() } ?: language.name
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
                        onLanguageSelected(language)
                    } catch (e: Exception) {
                        Log.w(TAG, "Language card click failed", e)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "LanguageViewHolder.bind failed", e)
            }
        }
    }

    private class LanguageDiffCallback : DiffUtil.ItemCallback<SupportedLanguage>() {
        override fun areItemsTheSame(oldItem: SupportedLanguage, newItem: SupportedLanguage): Boolean =
            oldItem.id == newItem.id
        override fun areContentsTheSame(oldItem: SupportedLanguage, newItem: SupportedLanguage): Boolean =
            oldItem == newItem
    }
}
