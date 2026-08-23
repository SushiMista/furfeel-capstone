import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Building2,
  Dog as DogIcon,
  Mail,
  Phone,
  RefreshCw,
  Search,
  UserCheck,
  Users as UsersIcon,
  UserPlus,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  fetchClinicTeams,
  type ClinicTeam,
  type ClinicTeamMember,
} from "../../lib/queries.ts";
import { friendlyError } from "../../lib/errors.ts";
import { Kpi } from "../overview/Overview.tsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Select } from "../../components/ui/input.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";

export function ClinicTeams() {
  const [teams, setTeams] = useState<ClinicTeam[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [clinicFilter, setClinicFilter] = useState("all");
  const [roleFilter, setRoleFilter] = useState("all");

  const loadTeams = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchClinicTeams(supabase);
      setTeams(data);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load clinic teams"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTeams();
  }, [loadTeams]);

  // Global KPIs
  const totalClinics = teams.length;
  const totalVets = useMemo(
    () => teams.reduce((acc, t) => acc + t.veterinarianCount, 0),
    [teams],
  );
  const totalStaff = useMemo(
    () => teams.reduce((acc, t) => acc + t.vetStaffCount, 0),
    [teams],
  );
  const totalDogs = useMemo(
    () => teams.reduce((acc, t) => acc + t.dogCount, 0),
    [teams],
  );

  // Filtered clinic team records
  const filteredTeams = useMemo(() => {
    return teams
      .filter((t) => clinicFilter === "all" || t.clinic.id === clinicFilter)
      .map((t) => {
        const filteredMembers = t.members.filter((m) => {
          if (m.role === "owner") return false;
          if (roleFilter !== "all" && m.role !== roleFilter) return false;
          if (search.trim() !== "") {
            const term = search.toLowerCase();
            const matchName = m.name.toLowerCase().includes(term);
            const matchEmail = m.email.toLowerCase().includes(term);
            const matchClinic = t.clinic.name.toLowerCase().includes(term);
            return matchName || matchEmail || matchClinic;
          }
          return true;
        });
        return {
          ...t,
          members: filteredMembers,
        };
      })
      .filter(
        (t) =>
          search.trim() === "" ||
          t.members.length > 0 ||
          t.clinic.name.toLowerCase().includes(search.toLowerCase()),
      );
  }, [teams, clinicFilter, roleFilter, search]);

  if (loading)
    return (
      <div className="flex flex-col gap-4">
        <CardSkeleton lines={2} />
        <CardSkeleton lines={6} />
      </div>
    );

  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-6">
      {/* Header & Page Description */}
      <div className="ff-enter">
        <h1 className="m-0 text-2xl font-bold text-ink">Clinic Teams &amp; Staff Roster</h1>
        <p className="m-0 mt-1 text-sm text-ink-muted">
          Partner clinics and assigned veterinarians and vet staff across the clinic network.
        </p>
      </div>

      {/* KPI Overview Cards */}
      <div className="ff-enter-list flex flex-wrap gap-4">
        <Kpi label="Partner clinics" value={String(totalClinics)} icon={<Building2 size={20} />} />
        <Kpi label="Veterinarians" value={String(totalVets)} icon={<UserCheck size={20} />} tone="positive" />
        <Kpi label="Vet staff" value={String(totalStaff)} icon={<UsersIcon size={20} />} />
        <Kpi label="Monitored dogs" value={String(totalDogs)} icon={<DogIcon size={20} />} />
      </div>

      {/* Search & Filter Bar */}
      <Card className="ff-enter">
        <CardContent className="p-4">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-ink-muted" />
              <Input
                type="text"
                placeholder="Search staff name, email, or clinic..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-8"
              />
            </div>
            <Select value={clinicFilter} onChange={(e) => setClinicFilter(e.target.value)}>
              <option value="all">All Partner Clinics</option>
              {teams.map((t) => (
                <option key={t.clinic.id} value={t.clinic.id}>
                  {t.clinic.name}
                </option>
              ))}
            </Select>
            <Select value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
              <option value="all">All Staff Roles</option>
              <option value="veterinarian">Veterinarians</option>
              <option value="vet_staff">Vet Staff</option>
              <option value="admin">Clinic Admins</option>
            </Select>
            <Button variant="secondary" onClick={loadTeams} disabled={loading}>
              <RefreshCw className={cn("mr-1.5 h-4 w-4", loading && "animate-spin")} /> Refresh Roster
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Clinic Teams Grid */}
      {filteredTeams.length === 0 ? (
        <EmptyState>No clinic team members found matching your search filters.</EmptyState>
      ) : (
        <div className="flex flex-col gap-6">
          {filteredTeams.map(({ clinic, members, dogCount }) => (
            <Card key={clinic.id} className="ff-enter overflow-hidden">
              <CardHeader className="border-b border-hairline bg-surface-alt/50 py-4">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <Building2 className="h-5 w-5 text-brand" />
                      <CardTitle className="text-lg font-bold text-ink">{clinic.name}</CardTitle>
                    </div>
                    {clinic.address && (
                      <CardDescription className="mt-1 text-xs text-ink-muted">
                        {clinic.address}
                        {clinic.contact_number && ` · Tel: ${clinic.contact_number}`}
                      </CardDescription>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-xs font-semibold">
                    <span className="rounded-full bg-brand-soft px-3 py-1 text-brand">
                      {members.length} {members.length === 1 ? "Staff Member" : "Staff Members"}
                    </span>
                    <span className="rounded-full bg-surface px-3 py-1 text-ink-muted border border-hairline">
                      {dogCount} {dogCount === 1 ? "Dog Monitored" : "Dogs Monitored"}
                    </span>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="p-5">
                {members.length === 0 ? (
                  <p className="m-0 text-xs italic text-ink-muted">
                    No active staff members currently assigned to {clinic.name}.
                  </p>
                ) : (
                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    {members.map((member) => (
                      <StaffMemberCard key={member.id} member={member} />
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

function StaffMemberCard({ member }: { member: ClinicTeamMember }) {
  const initials = member.name
    .split(" ")
    .map((part) => part[0])
    .filter(Boolean)
    .slice(0, 2)
    .join("")
    .toUpperCase();

  return (
    <div className="flex items-start gap-3.5 rounded-lg border border-hairline bg-surface p-4 shadow-xs transition-all hover:border-brand/30 hover:shadow-sm">
      <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-full bg-brand-soft text-brand font-bold text-sm">
        {initials || <UsersIcon size={20} />}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between gap-1">
          <h4 className="m-0 truncate text-sm font-bold text-ink">{member.name}</h4>
          <RoleBadge role={member.role} />
        </div>
        <div className="mt-1 flex flex-col gap-0.5 text-xs text-ink-muted">
          <a
            href={`mailto:${member.email}`}
            className="flex items-center gap-1.5 truncate text-ink-muted hover:text-brand hover:underline"
          >
            <Mail size={12} className="flex-shrink-0" />
            <span className="truncate">{member.email}</span>
          </a>
          {member.phone && (
            <div className="flex items-center gap-1.5">
              <Phone size={12} className="flex-shrink-0" />
              <span>{member.phone}</span>
            </div>
          )}
          <div className="mt-1 text-[11px] text-ink-muted">
            Joined {new Date(member.created_at).toLocaleDateString(undefined, { month: "short", year: "numeric" })}
          </div>
        </div>
      </div>
    </div>
  );
}

function RoleBadge({ role }: { role: ClinicTeamMember["role"] }) {
  switch (role) {
    case "veterinarian":
      return (
        <span className="inline-flex items-center rounded-full bg-calm-soft px-2 py-0.5 text-[10px] font-bold text-calm-fg">
          Veterinarian
        </span>
      );
    case "vet_staff":
      return (
        <span className="inline-flex items-center rounded-full bg-brand-soft px-2 py-0.5 text-[10px] font-bold text-brand-strong">
          Vet Staff
        </span>
      );
    case "admin":
      return (
        <span className="inline-flex items-center rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-800">
          Admin
        </span>
      );
    default:
      return (
        <span className="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-bold text-gray-700 capitalize">
          {role}
        </span>
      );
  }
}
