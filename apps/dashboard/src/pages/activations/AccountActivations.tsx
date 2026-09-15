import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient.ts";
import { activateUserAccount } from "../../lib/adminQueries.ts";
import { useCurrentRole } from "../../lib/useCurrentRole.ts";
import { friendlyError } from "../../lib/errors.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { UserCheck } from "lucide-react";
import { useToast } from "../../components/ui/toast.tsx";
import type { User } from "../../../../../packages/shared/types/index.ts";

export function AccountActivations() {
  const { role, loading: roleLoading } = useCurrentRole();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();

  useEffect(() => {
    if (roleLoading) return;
    
    const load = async () => {
      try {
        const { data, error } = await supabase
          .from("users")
          .select("id, name, email, role, clinic_id, is_active, deactivated_at, created_at")
          .eq("is_active", false)
          .eq("role", "owner")
          .is("deactivated_at", null)
          .order("created_at", { ascending: false });
          
        if (error) throw error;
        setUsers(data as unknown as User[]);
      } catch (err) {
        setError(friendlyError(err, "load pending activations"));
      } finally {
        setLoading(false);
      }
    };
    
    load();
  }, [roleLoading]);

  const handleActivate = async (userId: string) => {
    try {
      await activateUserAccount(supabase, userId);
      setUsers((prev) => prev.filter((u) => u.id !== userId));
      toast("success", "Account activated successfully.");
    } catch (err) {
      toast("error", friendlyError(err, "activate account"));
    }
  };

  if (roleLoading || loading) return <div>Loading...</div>;
  if (error) return <div className="text-red-500">{error}</div>;
  
  if (role === "owner") return <EmptyState>Access denied.</EmptyState>;

  return (
    <div className="flex flex-col gap-6">
      <div className="ff-enter">
        <h1 className="m-0 text-2xl font-bold text-ink">Account Activations</h1>
        <p className="m-0 mt-1 text-sm text-ink-muted">
          Review and activate newly registered patient owners.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Pending Accounts</CardTitle>
          <CardDescription>
            These owners have registered via the mobile app and are waiting for clinic verification before they can use the app.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {users.length === 0 ? (
            <EmptyState>No pending accounts.</EmptyState>
          ) : (
            <Table>
              <THead>
                <Tr>
                  <Th>Name</Th>
                  <Th>Email</Th>
                  <Th>Registered</Th>
                  <Th>Action</Th>
                </Tr>
              </THead>
              <TBody>
                {users.map((u) => (
                  <Tr key={u.id}>
                    <Td className="font-semibold">{u.name}</Td>
                    <Td className="text-ink-muted">{u.email}</Td>
                    <Td className="text-ink-muted">{new Date(u.created_at).toLocaleDateString()}</Td>
                    <Td>
                      <Button size="sm" onClick={() => handleActivate(u.id)} className="gap-2 bg-blue-600 hover:bg-blue-700">
                        <UserCheck size={14} /> Activate
                      </Button>
                    </Td>
                  </Tr>
                ))}
              </TBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
