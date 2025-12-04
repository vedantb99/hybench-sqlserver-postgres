import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# --- Configuration ---
INPUT_FILE = "recall_comparision.csv" # Ensure your data is in this file
# ---------------------

def plot_comparison():
    try:
        df = pd.read_csv(INPUT_FILE)
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_FILE}'. Please create it with your data first.")
        return

    # Set the visual style
    sns.set_theme(style="whitegrid")
    
    # Get unique queries to create subplots if needed, or just plot all
    # For a clean report, we usually plot one query per chart or use facets.
    # Here, we'll use a FacetGrid to handle multiple queries automatically.

    # --- 1. LATENCY COMPARISON (Lower is Better) ---
    g1 = sns.catplot(
        data=df, 
        x="K", 
        y="Latency", 
        hue="System", 
        col="Query", 
        kind="bar", 
        height=5, 
        aspect=1,
        palette="viridis",
        sharey=False # Allow different y-scales for different queries
    )
    
    g1.set_axis_labels("K (Top N)", "Latency (ms)")
    g1.fig.subplots_adjust(top=0.85)
    g1.fig.suptitle('Latency Comparison: SQL Server vs. PostgreSQL', fontsize=16)
    
    # Add value labels on bars
    for ax in g1.axes.flat:
        for container in ax.containers:
            ax.bar_label(container, fmt='%.0f', padding=3, fontsize=9)
            
    g1.savefig("comparison_latency.png", dpi=300)
    print("Generated comparison_latency.png")


    # --- 2. RECALL COMPARISON (Higher is Better) ---
    g2 = sns.relplot(
        data=df,
        x="K",
        y="Recall",
        hue="System",
        col="Query",
        kind="line",
        marker="o",
        height=5,
        aspect=1,
        linewidth=3,
        palette="deep"
    )

    g2.set_axis_labels("K (Top N)", "Recall (%)")
    g2.set(ylim=(0, 105)) # Force y-axis to show 0-100% range
    g2.fig.subplots_adjust(top=0.85)
    g2.fig.suptitle('Recall Comparison: SQL Server vs. PostgreSQL', fontsize=16)

    g2.savefig("comparison_recall.png", dpi=300)
    print("Generated comparison_recall.png")

if __name__ == "__main__":
    # Create a dummy CSV if it doesn't exist so you can see how it works
    import os
    if not os.path.exists(INPUT_FILE):
        print(f"Creating dummy '{INPUT_FILE}' for demonstration...")
        data = {
            "System": ["SQL Server"]*3 + ["PostgreSQL"]*3,
            "Query": ["Q1"]*6,
            "K": [10, 100, 1000, 10, 100, 1000],
            "Recall": [100, 100, 99.5, 100, 99.8, 95.0],
            "Latency": [8, 23, 150, 12, 45, 200]
        }
        pd.DataFrame(data).to_csv(INPUT_FILE, index=False)
        
    plot_comparison()