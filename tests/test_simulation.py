"""
Unit tests for Monte Carlo simulation modules
"""

import sys
sys.path.insert(0, '/workspaces/Process-SEM/src')

import numpy as np
import pytest
from monte_carlo import (
    MonteCarloSimulator,
    SimulationConfig,
    example_data_generator,
    example_estimator
)
from utils import (
    calculate_bias,
    calculate_mse,
    calculate_coverage,
    generate_correlation_matrix
)


def test_simulation_config():
    """Test SimulationConfig initialization"""
    config = SimulationConfig(n_simulations=100, sample_size=50)
    assert config.n_simulations == 100
    assert config.sample_size == 50
    assert config.random_seed == 42


def test_monte_carlo_simulator_init():
    """Test MonteCarloSimulator initialization"""
    config = SimulationConfig(n_simulations=10, sample_size=30)
    simulator = MonteCarloSimulator(config)
    assert simulator.config.n_simulations == 10
    assert len(simulator.results) == 0


def test_data_generator():
    """Test example data generator"""
    np.random.seed(42)
    data = example_data_generator(sample_size=100, n_variables=3, correlation=0.5)
    
    assert data.shape == (100, 3)
    assert not np.isnan(data).any()
    assert not np.isinf(data).any()


def test_estimator():
    """Test example estimator"""
    np.random.seed(42)
    data = np.random.randn(100, 3)
    results = example_estimator(data)
    
    assert results['converged'] == True
    assert 'parameters' in results
    assert 'standard_errors' in results
    assert 'fit_indices' in results


def test_monte_carlo_run():
    """Test full Monte Carlo simulation run"""
    config = SimulationConfig(n_simulations=5, sample_size=50, random_seed=42)
    simulator = MonteCarloSimulator(config)
    
    results_df = simulator.run(
        data_generator=example_data_generator,
        estimator=example_estimator,
        n_variables=2,
        correlation=0.5
    )
    
    assert len(results_df) <= 5
    assert 'iteration' in results_df.columns


def test_calculate_bias():
    """Test bias calculation"""
    estimates = np.array([1.0, 1.1, 0.9, 1.05, 0.95])
    true_value = 1.0
    bias = calculate_bias(estimates, true_value)
    assert abs(bias) < 0.1


def test_calculate_mse():
    """Test MSE calculation"""
    estimates = np.array([1.0, 1.1, 0.9, 1.05, 0.95])
    true_value = 1.0
    mse = calculate_mse(estimates, true_value)
    assert mse >= 0


def test_calculate_coverage():
    """Test coverage calculation"""
    np.random.seed(42)
    estimates = np.random.normal(1.0, 0.1, 100)
    standard_errors = np.full(100, 0.1)
    true_value = 1.0
    
    coverage = calculate_coverage(estimates, standard_errors, true_value)
    assert 0 <= coverage <= 1


def test_generate_correlation_matrix():
    """Test correlation matrix generation"""
    corr_matrix = generate_correlation_matrix(n_vars=3, base_correlation=0.3)
    
    assert corr_matrix.shape == (3, 3)
    assert np.allclose(np.diag(corr_matrix), 1.0)
    assert np.allclose(corr_matrix, corr_matrix.T)
    
    # Check positive definiteness
    eigenvalues = np.linalg.eigvals(corr_matrix)
    assert np.all(eigenvalues > 0)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
