import { AuthProvider } from "@/context/auth-context";
import "./dashboard.css";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <div className="dash-root">{children}</div>
    </AuthProvider>
  );
}
