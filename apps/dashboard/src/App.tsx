import type { ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "./lib/useAuth.ts";
import { AppShell } from "./components/AppShell.tsx";
import { ToastProvider } from "./components/ui/toast.tsx";
import { CardSkeleton } from "./components/ui/skeleton.tsx";
import { Login } from "./pages/login/Login.tsx";
import { Overview } from "./pages/overview/Overview.tsx";
import { MonitoringBoard } from "./pages/monitoring_board/MonitoringBoard.tsx";
import { DogDetail } from "./pages/dog_detail/DogDetail.tsx";
import { AlertsQueue } from "./pages/alerts/AlertsQueue.tsx";
import { Reports } from "./pages/reports/Reports.tsx";
import { VetReview } from "./pages/vet_review/VetReview.tsx";
import { Admin } from "./pages/admin/Admin.tsx";

function RequireAuth({ children }: { children: ReactNode }) {
  const { session, loading } = useAuth();
  if (loading)
    return (
      <div className="p-8">
        <CardSkeleton />
      </div>
    );
  if (!session) return <Navigate to="/login" replace />;
  return <AppShell>{children}</AppShell>;
}

export function App() {
  const { session, loading } = useAuth();

  return (
    <BrowserRouter>
      <ToastProvider>
        <Routes>
          <Route
            path="/login"
            element={
              loading ? (
                <div className="p-8">
                  <CardSkeleton />
                </div>
              ) : session ? (
                <Navigate to="/" replace />
              ) : (
                <Login />
              )
            }
          />
          <Route
            path="/"
            element={
              <RequireAuth>
                <Overview />
              </RequireAuth>
            }
          />
          <Route
            path="/board"
            element={
              <RequireAuth>
                <MonitoringBoard />
              </RequireAuth>
            }
          />
          <Route
            path="/dogs/:dogId"
            element={
              <RequireAuth>
                <DogDetail />
              </RequireAuth>
            }
          />
          <Route
            path="/dogs/:dogId/review"
            element={
              <RequireAuth>
                <VetReview />
              </RequireAuth>
            }
          />
          <Route
            path="/admin"
            element={
              <RequireAuth>
                <Admin />
              </RequireAuth>
            }
          />
          <Route
            path="/alerts"
            element={
              <RequireAuth>
                <AlertsQueue />
              </RequireAuth>
            }
          />
          <Route
            path="/reports"
            element={
              <RequireAuth>
                <Reports />
              </RequireAuth>
            }
          />
        </Routes>
      </ToastProvider>
    </BrowserRouter>
  );
}
