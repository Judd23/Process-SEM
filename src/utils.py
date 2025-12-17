"""
Utility functions for Monte Carlo simulations
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)


def calculate_bias(estimates: np.ndarray, true_value: float) -> float:
    """
    Calculate bias of parameter estimates.
    
    Args:
        estimates: Array of parameter estimates
        true_value: True parameter value
        
    Returns:
        Bias (mean estimate - true value)
    """
    return np.mean(estimates) - true_value


def calculate_mse(estimates: np.ndarray, true_value: float) -> float:
    """
    Calculate mean squared error of parameter estimates.
    
    Args:
        estimates: Array of parameter estimates
        true_value: True parameter value
        
    Returns:
        Mean squared error
    """
    return np.mean((estimates - true_value) ** 2)


def calculate_coverage(
    estimates: np.ndarray,
    standard_errors: np.ndarray,
    true_value: float,
    confidence_level: float = 0.95
) -> float:
    """
    Calculate coverage rate of confidence intervals.
    
    Args:
        estimates: Array of parameter estimates
        standard_errors: Array of standard errors
        true_value: True parameter value
        confidence_level: Confidence level (default 0.95)
        
    Returns:
        Coverage rate (proportion of intervals containing true value)
    """
    from scipy import stats
    
    z_critical = stats.norm.ppf((1 + confidence_level) / 2)
    
    lower_bounds = estimates - z_critical * standard_errors
    upper_bounds = estimates + z_critical * standard_errors
    
    coverage = np.mean((lower_bounds <= true_value) & (true_value <= upper_bounds))
    
    return coverage


def calculate_relative_bias(estimates: np.ndarray, true_value: float) -> float:
    """
    Calculate relative bias as percentage.
    
    Args:
        estimates: Array of parameter estimates
        true_value: True parameter value
        
    Returns:
        Relative bias as percentage
    """
    if true_value == 0:
        return np.nan
    
    return (calculate_bias(estimates, true_value) / true_value) * 100


def calculate_power(p_values: np.ndarray, alpha: float = 0.05) -> float:
    """
    Calculate statistical power (rejection rate).
    
    Args:
        p_values: Array of p-values
        alpha: Significance level (default 0.05)
        
    Returns:
        Power (proportion of significant results)
    """
    return np.mean(p_values < alpha)


def create_summary_table(
    results_df: pd.DataFrame,
    true_values: Optional[Dict[str, float]] = None,
    confidence_level: float = 0.95
) -> pd.DataFrame:
    """
    Create a comprehensive summary table of simulation results.
    
    Args:
        results_df: DataFrame with simulation results
        true_values: Dictionary of true parameter values
        confidence_level: Confidence level for coverage calculation
        
    Returns:
        Summary DataFrame
    """
    summary_rows = []
    
    # Get parameter columns
    param_cols = [col for col in results_df.columns if col.startswith('est_')]
    
    for col in param_cols:
        param_name = col.replace('est_', '')
        estimates = results_df[col].values
        
        row = {
            'Parameter': param_name,
            'Mean': np.mean(estimates),
            'Median': np.median(estimates),
            'SD': np.std(estimates),
            'Min': np.min(estimates),
            'Max': np.max(estimates),
            'Q25': np.percentile(estimates, 25),
            'Q75': np.percentile(estimates, 75)
        }
        
        # Add bias and MSE if true values provided
        if true_values and param_name in true_values:
            true_val = true_values[param_name]
            row['True_Value'] = true_val
            row['Bias'] = calculate_bias(estimates, true_val)
            row['Relative_Bias_%'] = calculate_relative_bias(estimates, true_val)
            row['MSE'] = calculate_mse(estimates, true_val)
            
            # Calculate coverage if standard errors available
            se_col = f'se_{param_name}'
            if se_col in results_df.columns:
                standard_errors = results_df[se_col].values
                row['Coverage'] = calculate_coverage(
                    estimates, standard_errors, true_val, confidence_level
                )
        
        summary_rows.append(row)
    
    return pd.DataFrame(summary_rows)


def plot_parameter_distributions(
    results_df: pd.DataFrame,
    true_values: Optional[Dict[str, float]] = None,
    save_path: Optional[str] = None
):
    """
    Create distribution plots for all estimated parameters.
    
    Args:
        results_df: DataFrame with simulation results
        true_values: Dictionary of true parameter values (optional)
        save_path: Path to save the plot (optional)
    """
    param_cols = [col for col in results_df.columns if col.startswith('est_')]
    
    n_params = len(param_cols)
    n_cols = min(3, n_params)
    n_rows = (n_params + n_cols - 1) // n_cols
    
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(5*n_cols, 4*n_rows))
    if n_params == 1:
        axes = np.array([axes])
    axes = axes.flatten()
    
    for idx, col in enumerate(param_cols):
        param_name = col.replace('est_', '')
        ax = axes[idx]
        
        # Plot histogram
        ax.hist(results_df[col], bins=30, alpha=0.6, edgecolor='black', density=True)
        
        # Plot KDE
        results_df[col].plot(kind='density', ax=ax, color='blue', linewidth=2)
        
        # Add vertical line for true value if provided
        if true_values and param_name in true_values:
            ax.axvline(true_values[param_name], color='red', 
                      linestyle='--', linewidth=2, label='True Value')
        
        # Add vertical line for mean
        mean_val = results_df[col].mean()
        ax.axvline(mean_val, color='green', linestyle=':', 
                  linewidth=2, label=f'Mean={mean_val:.3f}')
        
        ax.set_xlabel(param_name)
        ax.set_ylabel('Density')
        ax.set_title(f'Distribution of {param_name}')
        ax.legend()
        ax.grid(True, alpha=0.3)
    
    # Hide unused subplots
    for idx in range(n_params, len(axes)):
        axes[idx].set_visible(False)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        logger.info(f"Plot saved to {save_path}")
    
    plt.show()


def plot_convergence_over_iterations(
    results_df: pd.DataFrame,
    param_name: str,
    true_value: Optional[float] = None,
    save_path: Optional[str] = None
):
    """
    Plot cumulative mean over iterations to assess convergence.
    
    Args:
        results_df: DataFrame with simulation results
        param_name: Parameter name to plot
        true_value: True parameter value (optional)
        save_path: Path to save the plot (optional)
    """
    col_name = f'est_{param_name}'
    
    if col_name not in results_df.columns:
        logger.error(f"Parameter {param_name} not found in results")
        return
    
    cumulative_mean = results_df[col_name].expanding().mean()
    
    plt.figure(figsize=(10, 6))
    plt.plot(cumulative_mean.index, cumulative_mean.values, 
            linewidth=2, label='Cumulative Mean')
    
    if true_value is not None:
        plt.axhline(true_value, color='red', linestyle='--', 
                   linewidth=2, label='True Value')
    
    plt.xlabel('Iteration')
    plt.ylabel(f'Cumulative Mean of {param_name}')
    plt.title(f'Convergence of {param_name} Estimate')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        logger.info(f"Plot saved to {save_path}")
    
    plt.show()


def generate_correlation_matrix(n_vars: int, base_correlation: float = 0.3) -> np.ndarray:
    """
    Generate a positive definite correlation matrix.
    
    Args:
        n_vars: Number of variables
        base_correlation: Base correlation between variables
        
    Returns:
        Correlation matrix
    """
    # Create base correlation matrix
    corr_matrix = np.full((n_vars, n_vars), base_correlation)
    np.fill_diagonal(corr_matrix, 1.0)
    
    # Ensure positive definiteness by adjusting eigenvalues if needed
    eigenvalues, eigenvectors = np.linalg.eig(corr_matrix)
    
    if np.any(eigenvalues < 0):
        # Make all eigenvalues positive
        eigenvalues = np.maximum(eigenvalues, 0.01)
        corr_matrix = eigenvectors @ np.diag(eigenvalues) @ eigenvectors.T
        
        # Rescale to have 1s on diagonal
        D = np.diag(1.0 / np.sqrt(np.diag(corr_matrix)))
        corr_matrix = D @ corr_matrix @ D
    
    return corr_matrix


def export_results_to_latex(summary_df: pd.DataFrame, filename: str = "results/summary_table.tex"):
    """
    Export summary table to LaTeX format.
    
    Args:
        summary_df: Summary DataFrame
        filename: Output filename
    """
    latex_str = summary_df.to_latex(index=False, float_format="%.4f")
    
    with open(filename, 'w') as f:
        f.write(latex_str)
    
    logger.info(f"LaTeX table saved to {filename}")
