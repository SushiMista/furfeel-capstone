import type { ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes, useParams } from "react-router-dom";
import { useAuth, signOut } from "./lib/useAuth.ts";
import { useCurrentRole } from "./lib/useCurrentRole.ts";
import { AppShell } from "./components/AppShell.tsx";
import { ToastProvider } from "./components/ui/toast.tsx";
import { CardSkeleton } from "./components/ui/skeleton.tsx";
import { Login } from "./pages/login/Login.tsx";
import { Overview } from "./pages/overview/Overview.tsx";
import { MonitoringBoard } from "./pages/monitoring_board/MonitoringBoard.tsx";
import { DogDetail } from "./pages/dog_detail/DogDetail.tsx";
import { AlertsQueue } from "./pages/alerts/AlertsQueue.tsx";
import { Handover } from "./pages/handover/Handover.tsx";
import { Devices } from "./pages/devices/Devices.tsx";
import { Reports } from "./pages/reports/Reports.tsx";
import { HeatmapAnalytics } from "./pages/heatmap/HeatmapAnalytics.tsx";
import { Admin } from "./pages/admin/Admin.tsx";

function RequireAuth({ children }: { children: ReactNode }) {
  const { session, loading: authLoading } = useAuth();
  const { role, loading: roleLoading } = useCurrentRole();

  if (authLoading || (session && roleLoading))
    return (
      <div className="p-8">
        <CardSkeleton />
      </div>
    );
  if (!session) return <Navigate to="/login" replace />;

  if (role === "owner") {
    signOut();
    return <Navigate to="/login?error=owner_restricted" replace />;
  }

  return <AppShell>{children}</AppShell>;
}

function ReviewRedirect() {
  const { dogId } = useParams<{ dogId: string }>();
  return <Navigate to={`/dogs/${dogId}?tab=review`} replace />;
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
                <ReviewRedirect />
              </RequireAuth>
            }
          />
          <Route path="/admin" element={<Navigate to="/admin/users" replace />} />
          <Route
            path="/admin/:tab"
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
          <Route
            path="/handover"
            element={
              <RequireAuth>
                <Handover />
              </RequireAuth>
            }
          />
          <Route
            path="/devices"
            element={
              <RequireAuth>
                <Devices />
              </RequireAuth>
            }
          />
          <Route
            path="/heatmap"
            element={
              <RequireAuth>
                <HeatmapAnalytics />
              </RequireAuth>
            }
          />
        </Routes>
      </ToastProvider>
    </BrowserRouter>
  );
}
