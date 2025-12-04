import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# --- Configuration ---
INPUT_FILE = "recall_comparision.csv" # Note: using your filename with 'comparision' typo
# ---------------------

def plot_comparison():
    try:
        df = pd.read_csv(INPUT_FILE)
    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_FILE}'. Please make sure the file exists.")
        return

    # Set a clean visual style
    sns.set_theme(style="whitegrid")
    
    # --- 1. LATENCY COMPARISON (Lower is Better) ---
    # We use a bar chart because K values are discrete categories
    g1 = sns.catplot(
        data=df, 
        x="K", 
        y="Latency", 
        hue="System", 
        col="Query", 
        kind="bar", 
        height=5, 
        aspect=0.8,
        palette="viridis",
        sharey=False # Different queries have vastly different latencies
    )
    
    g1.set_axis_labels("K (Top N)", "Latency (ms)")
    g1.fig.subplots_adjust(top=0.85)
    g1.fig.suptitle('Latency: SQL Server vs. PostgreSQL (lists=800, probes=20)', fontsize=16, fontweight='bold')
    
    # Add numerical labels on top of bars for clarity
    for ax in g1.axes.flat:
        for container in ax.containers:
            ax.bar_label(container, fmt='%.0f', padding=3, fontsize=9)
            
    g1.savefig("comparison_latency.png", dpi=300, bbox_inches='tight')
    print("Generated comparison_latency.png")


    # --- 2. RECALL COMPARISON (Higher is Better) ---
    # We use a line chart to show the trend/stability
    g2 = sns.relplot(
        data=df,
        x="K",
        y="Recall",
        hue="System",
        col="Query",
        kind="line",
        marker="o",
        height=5,
        aspect=0.8,
        linewidth=3,
        palette="deep"
    )

    g2.set_axis_labels("K (Top N)", "Recall (%)")
    g2.set(ylim=(0, 105)) # Fix Y-axis to 0-100% for fair comparison
    g2.fig.subplots_adjust(top=0.85)
    g2.fig.suptitle('Recall Stability: SQL Server vs. PostgreSQL', fontsize=16, fontweight='bold')

    # Add simple annotations for the last point to help readability
    for ax in g2.axes.flat:
        # Get the data for this subplot (specific query)
        query_title = ax.get_title().split('=')[1].strip()
        query_data = df[df['Query'] == query_title]
        
        # Annotate the final K value for each system
        for system in query_data['System'].unique():
            last_point = query_data[query_data['System'] == system].iloc[-1]
            ax.text(
                last_point['K'], 
                last_point['Recall'] + 2, 
                f"{last_point['Recall']:.1f}%", 
                fontsize=9, 
                color='black', 
                ha='center'
            )

    g2.savefig("comparison_recall.png", dpi=300, bbox_inches='tight')
    print("Generated comparison_recall.png")

if __name__ == "__main__":
    plot_comparison()
