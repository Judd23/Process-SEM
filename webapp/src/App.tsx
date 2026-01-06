import { HashRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { AnimatePresence } from 'framer-motion';
import { ResearchProvider } from './context/ResearchContext';
import { ThemeProvider } from './context/ThemeContext';
import { ModelDataProvider } from './context/ModelDataContext';
import Layout from './components/layout/Layout';
import PageTransition from './components/layout/PageTransition';
import ScrollToTop from './components/ui/ScrollToTop';
import LandingPage from './pages/LandingPage';
import HomePage from './pages/HomePage';
import SoWhatPage from './pages/SoWhatPage';
import DoseExplorerPage from './pages/DoseExplorerPage';
import DemographicsPage from './pages/DemographicsPage';
import PathwayPage from './pages/PathwayPage';
import MethodsPage from './pages/MethodsPage';
import ResearcherPage from './pages/ResearcherPage';
import './styles/global.css';

function AnimatedRoutes() {
  const location = useLocation();

  return (
    <AnimatePresence mode="wait" initial={false}>
      <Routes location={location} key={location.pathname}>
        <Route
          index
          element={
            <PageTransition>
              <LandingPage />
            </PageTransition>
          }
        />
        <Route path="/" element={<Layout />}>
          <Route path="home" element={<HomePage />} />
          <Route path="so-what" element={<SoWhatPage />} />
          <Route path="dose" element={<DoseExplorerPage />} />
          <Route path="demographics" element={<DemographicsPage />} />
          <Route path="pathway" element={<PathwayPage />} />
          <Route path="methods" element={<MethodsPage />} />
          <Route path="researcher" element={<ResearcherPage />} />
          <Route path="about" element={<Navigate to="/researcher" replace />} />
          <Route path="*" element={<Navigate to="/home" replace />} />
        </Route>
      </Routes>
    </AnimatePresence>
  );
}

function App() {
  return (
    <ThemeProvider>
      <ModelDataProvider>
        <ResearchProvider>
          <HashRouter>
            <ScrollToTop />
            <AnimatedRoutes />
          </HashRouter>
        </ResearchProvider>
      </ModelDataProvider>
    </ThemeProvider>
  );
}

export default App;
