import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# --- Configuration ---
INPUT_FILE = "recall_comparision.csv"
LATENCY_OUTPUT = "slide9_latency.png"
RECALL_OUTPUT = "slide9_recall.png"
# ---------------------

def plot_slide9_metrics():
    try:
        # Read the CSV
        df = pd.read_csv(INPUT_FILE)
        
        # Filter for SQL Server only (since the slide title is "SQLServer Results")
        df_sql = df[df['System'] == 'SQL Server'].copy()
        
        if df_sql.empty:
            print("Error: No SQL Server data found in CSV.")
            return

        # Set visual style
        sns.set_theme(style="whitegrid", context="talk") # 'talk' context makes fonts larger for PPTs

        # --- PLOT 1: Index Latency vs K ---
        plt.figure(figsize=(8, 6))
        g1 = sns.lineplot(
            data=df_sql, 
            x="K", 
            y="Latency", 
            hue="Query", 
            marker="o", 
            linewidth=3,
            palette="viridis"
        )
        
        g1.set_title("Index Search Latency", fontsize=16, fontweight='bold')
        g1.set_xlabel("K (Top N)", fontsize=14)
        g1.set_ylabel("Latency (ms)", fontsize=14)
        g1.legend(title="Query Type", fontsize=10, title_fontsize=12)
        plt.tight_layout()
        plt.savefig(LATENCY_OUTPUT, dpi=300)
        print(f"Generated {LATENCY_OUTPUT}")
        plt.close()

        # --- PLOT 2: Recall vs K ---
        plt.figure(figsize=(8, 6))
        g2 = sns.lineplot(
            data=df_sql, 
            x="K", 
            y="Recall", 
            hue="Query", 
            marker="s", 
            linewidth=3,
            palette="magma"
        )
        
        g2.set_title("Recall Stability", fontsize=16, fontweight='bold')
        g2.set_xlabel("K (Top N)", fontsize=14)
        g2.set_ylabel("Recall (%)", fontsize=14)
        g2.set_ylim(0, 105) # Force 0-100% range
        
        # Add specific annotations for the drop in Q16
        # Find Q16 data points
        q16_data = df_sql[df_sql['Query'].str.contains('Q16')]
        if not q16_data.empty:
             # Annotate the last point for Q16
            last_point = q16_data.iloc[-1]
            plt.annotate(f"{last_point['Recall']:.0f}%", 
                         (last_point['K'], last_point['Recall']),
                         textcoords="offset points", 
                         xytext=(0,-15), 
                         ha='center', color='red', fontweight='bold')

        g2.legend(title="Query Type", fontsize=10, title_fontsize=12, loc='lower left')
        plt.tight_layout()
        plt.savefig(RECALL_OUTPUT, dpi=300)
        print(f"Generated {RECALL_OUTPUT}")
        plt.close()

    except FileNotFoundError:
        print(f"Error: Could not find '{INPUT_FILE}'.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    plot_slide9_metrics()