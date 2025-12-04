import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import textwrap

# --- Configuration ---
LATENCY_FILE = "latency_results.csv"
RECALL_FILE = "recall_results.csv"
# ---------------------

def plot_index_vs_scan(df_latency, df_recall):
    """
    Compares Latency of Indexable Queries (Index vs Full Scan).
    """
    if df_recall is None or df_recall.empty:
        print("Skipping Index vs Scan plot (Recall file missing).")
        return

    # Filter for K=100 for a clean chart
    k_val = 100 
    data = df_recall[df_recall['K'] == k_val].copy()
    
    if data.empty:
        print(f"No data found for K={k_val}")
        return

    queries = data['Query']
    x = np.arange(len(queries))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    rects1 = ax.bar(x - width/2, data['Exact_Latency_MS'], width, label='Non-Indexed (Full Scan)', color='#e74c3c')
    rects2 = ax.bar(x + width/2, data['Index_Latency_MS'], width, label='Indexed (Vector Search)', color='#2ecc71')

    ax.set_ylabel('Latency (ms) - Log Scale')
    ax.set_title(f'Impact of Vector Index (K={k_val})')
    ax.set_xticks(x)
    ax.set_xticklabels(queries)
    ax.legend()
    ax.set_yscale('log')
    
    ax.bar_label(rects1, fmt='%.0f', padding=3, fontsize=8)
    ax.bar_label(rects2, fmt='%.0f', padding=3, fontsize=8)

    plt.tight_layout()
    plt.savefig('graph_index_vs_scan.png')
    print("Generated graph_index_vs_scan.png")

def plot_rows_vs_latency(df_latency):
    """
    Shows how relational selectivity affects latency.
    """
    plt.figure(figsize=(10, 6))
    data = df_latency[df_latency['Status'] == 'Success']
    
    sns.scatterplot(data=data, x='Rows_Returned', y='Latency_MS', s=100, color='#3498db', alpha=0.7)
    
    plt.title('Impact of Result Size on Latency (Non-Indexed Queries)')
    plt.xlabel('Rows Returned (Selectivity)')
    plt.ylabel('Latency (ms)')
    plt.grid(True, linestyle='--', alpha=0.6)
    
    for i, row in data.iterrows():
        if row['Latency_MS'] > 1000 or row['Rows_Returned'] > 100000:
            plt.text(row['Rows_Returned']+500, row['Latency_MS'], f"Q{row['Query_ID']}", fontsize=9)

    plt.tight_layout()
    plt.savefig('graph_selectivity.png')
    print("Generated graph_selectivity.png")

def plot_latency_distribution(df_latency):
    """
    Categorizes queries by latency buckets and ANNOTATES them with Query IDs.
    Robust version that handles missing bars/categories safely.
    """
    data = df_latency[df_latency['Status'] == 'Success'].copy()
    
    # Define buckets
    bins = [0, 100, 500, 1000, 5000, 100000]
    labels = ['<100ms', '100-500ms', '500ms-1s', '1s-5s', '>5s']
    data['Bucket'] = pd.cut(data['Latency_MS'], bins=bins, labels=labels)
    
    plt.figure(figsize=(12, 8))
    
    # Create plot
    ax = sns.countplot(data=data, x='Bucket', palette='viridis', order=labels)
    
    plt.title('Latency Distribution of Non-Indexed Queries')
    plt.xlabel('Latency Range')
    plt.ylabel('Number of Queries')
    
    # Group queries by bucket (using observed=False to suppress warning and include all categories)
    try:
        bucket_groups = data.groupby('Bucket', observed=False)['Query_ID'].apply(list)
    except TypeError:
        # Fallback for older pandas versions
        bucket_groups = data.groupby('Bucket')['Query_ID'].apply(list)
    
    # --- FIXED ANNOTATION LOOP ---
    # Instead of assuming ax.patches[i] maps to labels[i], we iterate through
    # the patches that actually exist and calculate their position.
    for p in ax.patches:
        # Calculate the x-axis index this bar belongs to based on its position
        # Bars are centered at integer coordinates 0, 1, 2...
        x_coord = p.get_x() + p.get_width() / 2
        label_index = int(round(x_coord))
        
        # Safety check: ensure index is valid
        if 0 <= label_index < len(labels):
            label = labels[label_index]
            
            # Get queries for this bucket
            if label in bucket_groups:
                q_ids = bucket_groups[label]
                
                # Only annotate if there are actually queries in this bucket
                if isinstance(q_ids, list) and len(q_ids) > 0:
                    q_ids.sort()
                    # Format: "Q1, Q2, Q3..."
                    q_str = ", ".join([f"Q{q}" for q in q_ids])
                    
                    # Wrap text so it doesn't run off the screen
                    wrapped_text = "\n".join(textwrap.wrap(q_str, width=25))
                    
                    height = p.get_height()
                    
                    # Place text above the bar
                    ax.annotate(wrapped_text, 
                                (x_coord, height), 
                                ha = 'center', va = 'bottom', 
                                xytext = (0, 10), 
                                textcoords = 'offset points',
                                fontsize=9, color='black')

    # Increase y-limit to make room for the text labels
    plt.margins(y=0.3)
    
    plt.tight_layout()
    plt.savefig('graph_distribution.png')
    print("Generated graph_distribution.png")

if __name__ == "__main__":
    # Load Data
    try:
        df_lat = pd.read_csv(LATENCY_FILE)
    except:
        print("Could not load latency results.")
        df_lat = pd.DataFrame()

    try:
        df_rec = pd.read_csv(RECALL_FILE)
    except:
        print("Could not load recall results (Graph 1 will be skipped).")
        df_rec = pd.DataFrame()

    if not df_lat.empty:
        plot_rows_vs_latency(df_lat)
        plot_latency_distribution(df_lat)
        
    if not df_rec.empty:
        plot_index_vs_scan(df_lat, df_rec)