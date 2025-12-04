import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# --- Data for IQ1 (Q16) ---
data = [
    {"K": 10, "Recall": 100.0, "Latency": 48, "Speedup": 53.3},
    {"K": 20, "Recall": 100.0, "Latency": 15, "Speedup": 170.6},
    {"K": 30, "Recall": 100.0, "Latency": 16, "Speedup": 159.9},
    {"K": 50, "Recall": 100.0, "Latency": 31, "Speedup": 82.5},
    {"K": 100, "Recall": 100.0, "Latency": 35, "Speedup": 73.1},
    {"K": 200, "Recall": 80.0, "Latency": 76, "Speedup": 33.7}
]

df = pd.DataFrame(data)

# --- Plotting ---
sns.set_theme(style="whitegrid", context="talk")
fig, axes = plt.subplots(1, 3, figsize=(22, 6))
fig.suptitle('Deep Dive: IQ1 (Paginated Search) Performance', fontsize=22, weight='bold', y=1.05)

# Plot 1: Recall Degradation
sns.lineplot(ax=axes[0], data=df, x="K", y="Recall", marker="o", markersize=10, linewidth=3, color="#e74c3c")
axes[0].set_title("Recall Stability", fontsize=18)
axes[0].set_xlabel("End Rank (K)", fontsize=14)
axes[0].set_ylabel("Recall (%)", fontsize=14)
axes[0].set_ylim(50, 105)
# Highlight the drop
drop_point = df[df['K'] == 200].iloc[0]
axes[0].annotate(f"Drop to {drop_point['Recall']:.0f}%", 
                 (drop_point['K'], drop_point['Recall']), 
                 xytext=(-60, -40), textcoords='offset points',
                 arrowprops=dict(facecolor='black', shrink=0.05),
                 fontsize=12, color='red', weight='bold')

# Plot 2: Latency Trend
# Use barplot for clear comparison of discrete K values
sns.barplot(ax=axes[1], data=df, x="K", y="Latency", palette="viridis", hue="K", legend=False)
axes[1].set_title("Index Latency", fontsize=18)
axes[1].set_xlabel("End Rank (K)", fontsize=14)
axes[1].set_ylabel("Time (ms)", fontsize=14)
axes[1].bar_label(axes[1].containers[0], fmt='%.0f ms', padding=3, fontsize=12)

# Plot 3: Speedup Factor
sns.lineplot(ax=axes[2], data=df, x="K", y="Speedup", marker="^", markersize=12, linewidth=3, color="#2980b9")
axes[2].set_title("Speedup vs Full Scan", fontsize=18)
axes[2].set_xlabel("End Rank (K)", fontsize=14)
axes[2].set_ylabel("Speedup Factor (x)", fontsize=14)
# Annotate peak speedup
peak = df.loc[df['Speedup'].idxmax()]
axes[2].annotate(f"Peak: {peak['Speedup']}x", 
                 (peak['K'], peak['Speedup']), 
                 xytext=(10, 10), textcoords='offset points',
                 arrowprops=dict(facecolor='green', shrink=0.05),
                 fontsize=12, color='green', weight='bold')

plt.tight_layout()
plt.savefig("iq1_detailed_analysis.png", bbox_inches='tight', dpi=300)
print("Generated iq1_detailed_analysis.png")