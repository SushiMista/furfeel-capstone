import { useState, useEffect, useCallback, useMemo, type FormEvent, type ChangeEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Search,
  PawPrint,
  Radio,
  ExternalLink,
  Edit,
  Plus,
  Unlink,
  CheckCircle2,
  Calendar,
  Weight,
  User,
  Image as ImageIcon,
  X,
  Sparkles,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { useAuth } from "../../lib/useAuth.ts";
import {
  fetchDogs,
  getMediaSignedUrl,
  uploadDogPhoto,
  fetchDevicesReadOnly,
  type Dog,
  type DeviceWithDog,
} from "../../lib/queries.ts";
import {
  fetchAllUsers,
  updateDog,
  updateDevice,
} from "../../lib/adminQueries.ts";
import { seedInitialBiotelemetry } from "../../lib/biotelemetrySeeder.ts";
import type { User as AppUser, DogSex } from "../../../../../packages/shared/types/index.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { Badge } from "../../components/ui/badge.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Label, Select } from "../../components/ui/input.tsx";
import { Dialog } from "../../components/ui/dialog.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { friendlyError } from "../../lib/errors.ts";

export function DogManagement() {
  const navigate = useNavigate();
  const { profile } = useAuth();
  const { toast } = useToast();

  const [dogs, setDogs] = useState<Dog[]>([]);
  const [devices, setDevices] = useState<DeviceWithDog[]>([]);
  const [users, setUsers] = useState<AppUser[]>([]);
  const [signedPhotoUrls, setSignedPhotoUrls] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState("");
  const [breedFilter, setBreedFilter] = useState("all");

  // Modals state
  const [editingDog, setEditingDog] = useState<Dog | null>(null);
  const [pairingDog, setPairingDog] = useState<Dog | null>(null);
  const [saving, setSaving] = useState(false);

  // Edit form state
  const [editName, setEditName] = useState("");
  const [editBreed, setEditBreed] = useState("");
  const [editSex, setEditSex] = useState<DogSex>("unknown");
  const [editBirthdate, setEditBirthdate] = useState("");
  const [editWeightKg, setEditWeightKg] = useState("");
  const [editNotes, setEditNotes] = useState("");
  const [editPhotoFile, setEditPhotoFile] = useState<File | null>(null);
  const [editPhotoPreview, setEditPhotoPreview] = useState<string | null>(null);

  // Pairing state
  const [selectedCollarId, setSelectedCollarId] = useState<string>("");

  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      const [dList, devList, uList] = await Promise.all([
        fetchDogs(supabase),
        fetchDevicesReadOnly(supabase).catch(() => [] as DeviceWithDog[]),
        fetchAllUsers(supabase).catch(() => [] as AppUser[]),
      ]);

      setDogs(dList);
      setDevices(devList);
      setUsers(uList);
      setError(null);

      // Load signed photos for dogs with photo_path
      const dogsWithPhotos = dList.filter((d) => Boolean(d.photo_path));
      if (dogsWithPhotos.length > 0) {
        const urlEntries = await Promise.all(
          dogsWithPhotos.map(async (d) => {
            try {
              const url = await getMediaSignedUrl(supabase, d.photo_path!);
              return [d.id, url] as [string, string];
            } catch {
              return [d.id, ""] as [string, string];
            }
          }),
        );
        const validMap: Record<string, string> = {};
        for (const [id, url] of urlEntries) {
          if (url) validMap[id] = url;
        }
        setSignedPhotoUrls(validMap);
      }
    } catch (err) {
      setError(friendlyError(err, "load clinic patients"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Map users for fast owner name lookup
  const userMap = useMemo(() => {
    return new Map(users.map((u) => [u.id, u]));
  }, [users]);

  // Map devices by dog_id
  const dogDeviceMap = useMemo(() => {
    const map = new Map<string, DeviceWithDog>();
    for (const dev of devices) {
      if (dev.dog_id) {
        map.set(dev.dog_id, dev);
      }
    }
    return map;
  }, [devices]);

  // Unassigned devices available for pairing
  const availableDevices = useMemo(() => {
    return devices.filter((d) => !d.dog_id && d.status !== "maintenance");
  }, [devices]);

  // Unique breeds for filter
  const uniqueBreeds = useMemo(() => {
    const set = new Set<string>();
    for (const d of dogs) {
      if (d.breed?.trim()) set.add(d.breed.trim());
    }
    return Array.from(set).sort();
  }, [dogs]);

  // Filtered Dogs
  const filteredDogs = useMemo(() => {
    return dogs.filter((d) => {
      const q = searchQuery.toLowerCase().trim();
      const owner = userMap.get(d.owner_user_id);
      const ownerName = owner?.name?.toLowerCase() || "";
      const ownerEmail = owner?.email?.toLowerCase() || "";
      const device = dogDeviceMap.get(d.id);
      const deviceCode = device?.device_code?.toLowerCase() || "";

      const matchesSearch =
        !q ||
        d.name.toLowerCase().includes(q) ||
        (d.breed && d.breed.toLowerCase().includes(q)) ||
        ownerName.includes(q) ||
        ownerEmail.includes(q) ||
        deviceCode.includes(q);

      const matchesBreed = breedFilter === "all" || d.breed === breedFilter;

      return matchesSearch && matchesBreed;
    });
  }, [dogs, searchQuery, breedFilter, userMap, dogDeviceMap]);

  // Open Edit Modal
  function handleOpenEdit(dog: Dog) {
    setEditingDog(dog);
    setEditName(dog.name);
    setEditBreed(dog.breed || "");
    setEditSex((dog.sex as DogSex) || "unknown");
    setEditBirthdate(dog.birthdate || "");
    setEditWeightKg(dog.weight_kg != null ? String(dog.weight_kg) : "");
    setEditNotes(dog.notes || "");
    setEditPhotoFile(null);
    setEditPhotoPreview(signedPhotoUrls[dog.id] || null);
  }

  // Handle Photo selection in edit
  function handlePhotoChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setEditPhotoFile(file);
    const url = URL.createObjectURL(file);
    setEditPhotoPreview(url);
  }

  // Save Edit Dog Profile
  async function handleSaveEdit(e: FormEvent) {
    e.preventDefault();
    if (!editingDog) return;

    if (!editName.trim()) {
      toast("error", "Dog name cannot be empty.");
      return;
    }

    setSaving(true);
    try {
      let photoPath = editingDog.photo_path;
      if (editPhotoFile) {
        photoPath = await uploadDogPhoto(supabase, editingDog.id, editPhotoFile);
      }

      await updateDog(supabase, editingDog.id, {
        name: editName.trim(),
        breed: editBreed.trim() || null,
        sex: editSex || null,
        birthdate: editBirthdate || null,
        weight_kg: editWeightKg ? parseFloat(editWeightKg) : null,
        notes: editNotes.trim() || null,
        photo_path: photoPath,
      });

      toast("success", `Updated profile for ${editName.trim()}`);
      setEditingDog(null);
      await loadData();
    } catch (err) {
      toast("error", friendlyError(err, "update dog profile"));
    } finally {
      setSaving(false);
    }
  }

  // Open Pairing Modal
  function handleOpenPairing(dog: Dog) {
    setPairingDog(dog);
    setSelectedCollarId("");
  }

  // Save Collar Pairing
  async function handleSavePairing(e: FormEvent) {
    e.preventDefault();
    if (!pairingDog) return;

    setSaving(true);
    try {
      if (selectedCollarId) {
        // If dog already has a collar, unpair old collar first
        const currentDev = dogDeviceMap.get(pairingDog.id);
        if (currentDev && currentDev.id !== selectedCollarId) {
          await updateDevice(supabase, currentDev.id, { dog_id: null, status: "inactive" });
        }

        // Pair new collar
        await updateDevice(supabase, selectedCollarId, {
          dog_id: pairingDog.id,
          status: "active",
        });

        // Seed initial placeholder vitals if pairing to a collar
        await seedInitialBiotelemetry(supabase, {
          dogId: pairingDog.id,
          deviceId: selectedCollarId,
          count: 6,
        });

        toast("success", `Paired collar with ${pairingDog.name}`);
      }
      setPairingDog(null);
      await loadData();
    } catch (err) {
      toast("error", friendlyError(err, "pair collar"));
    } finally {
      setSaving(false);
    }
  }

  // Unpair Collar
  async function handleUnpairCollar(device: DeviceWithDog, dog: Dog) {
    if (!confirm(`Unpair collar ${device.device_code} from ${dog.name}?`)) return;

    try {
      await updateDevice(supabase, device.id, { dog_id: null, status: "inactive" });
      toast("success", `Unpaired collar ${device.device_code} from ${dog.name}`);
      await loadData();
    } catch (err) {
      toast("error", friendlyError(err, "unpair collar"));
    }
  }

  if (loading) return <CardSkeleton lines={8} />;

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="m-0 text-2xl font-black text-ink tracking-tight flex items-center gap-2.5">
            <PawPrint className="text-brand h-7 w-7" />
            <span>Patient Dogs Directory</span>
          </h1>
          <p className="text-sm text-ink-muted mt-1">
            Manage admitted canines, update physiological records, and bind telemetry hardware collars.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <Button
            type="button"
            onClick={() => navigate("/intake")}
            className="flex items-center gap-2 font-bold shadow-xs bg-brand hover:bg-brand-strong text-white"
          >
            <Plus size={16} />
            <span>+ Admit New Patient</span>
          </Button>
        </div>
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-high-soft px-4 py-3 text-sm font-semibold text-high-fg border border-high-fg/20">
          {error}
        </p>
      )}

      {/* Main Card */}
      <Card className="border-hairline shadow-xs">
        <CardHeader className="pb-4">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
            <div>
              <CardTitle className="text-lg font-bold text-ink">Clinic Patients ({filteredDogs.length})</CardTitle>
              <CardDescription>All canine patients registered in this clinical facility.</CardDescription>
            </div>

            {/* Filter & Search Bar */}
            <div className="flex flex-col sm:flex-row items-center gap-2.5 w-full md:w-auto">
              <div className="relative w-full sm:w-64">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted" />
                <Input
                  placeholder="Search patient, owner, collar..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-9 text-xs h-9"
                />
              </div>

              {uniqueBreeds.length > 0 && (
                <Select
                  value={breedFilter}
                  onChange={(e) => setBreedFilter(e.target.value)}
                  className="text-xs h-9 w-full sm:w-44"
                >
                  <option value="all">All Breeds ({uniqueBreeds.length})</option>
                  {uniqueBreeds.map((b) => (
                    <option key={b} value={b}>
                      {b}
                    </option>
                  ))}
                </Select>
              )}
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          {filteredDogs.length === 0 ? (
            <div className="p-8">
              <EmptyState>
                {dogs.length === 0
                  ? "No patient dogs admitted yet. Click '+ Admit New Patient' to begin intake."
                  : "No patients matched your search criteria."}
              </EmptyState>
            </div>
          ) : (
            <Table>
              <THead>
                <Tr className="border-t-0 bg-surface-alt/40">
                  <Th className="w-12"></Th>
                  <Th>Patient Name</Th>
                  <Th>Breed & Sex</Th>
                  <Th>Weight / Age</Th>
                  <Th>Pet Owner</Th>
                  <Th>Telemetry Collar</Th>
                  <Th className="text-right">Actions</Th>
                </Tr>
              </THead>
              <TBody>
                {filteredDogs.map((d) => {
                  const owner = userMap.get(d.owner_user_id);
                  const assignedDevice = dogDeviceMap.get(d.id);
                  const photoUrl = signedPhotoUrls[d.id];

                  return (
                    <Tr key={d.id} className="hover:bg-surface-alt/30 transition-colors">
                      {/* Photo Thumbnail */}
                      <Td className="py-2.5 pl-4">
                        <div className="h-10 w-10 rounded-xl overflow-hidden bg-brand-soft/60 border border-brand/20 flex items-center justify-center shrink-0">
                          {photoUrl ? (
                            <img src={photoUrl} alt={d.name} className="h-full w-full object-cover" />
                          ) : (
                            <PawPrint size={18} className="text-brand" />
                          )}
                        </div>
                      </Td>

                      {/* Patient Name */}
                      <Td>
                        <div className="flex flex-col">
                          <Link
                            to={`/dogs/${d.id}`}
                            className="font-black text-sm text-ink hover:text-brand hover:underline flex items-center gap-1.5"
                          >
                            <span>{d.name}</span>
                            <ExternalLink size={12} className="opacity-50" />
                          </Link>
                          {d.notes && (
                            <span className="text-[11px] text-ink-muted line-clamp-1 max-w-[200px]" title={d.notes}>
                              {d.notes}
                            </span>
                          )}
                        </div>
                      </Td>

                      {/* Breed & Sex */}
                      <Td>
                        <div className="flex flex-col gap-0.5">
                          <span className="text-xs font-semibold text-ink">{d.breed || "Unspecified"}</span>
                          <span className="text-[11px] text-ink-muted capitalize">{d.sex || "unknown"}</span>
                        </div>
                      </Td>

                      {/* Weight / Age */}
                      <Td>
                        <div className="flex flex-col gap-0.5 text-xs text-ink-muted">
                          <span className="font-semibold text-ink">
                            {d.weight_kg != null ? `${d.weight_kg} kg` : "—"}
                          </span>
                          <span className="text-[11px]">
                            {d.birthdate ? d.birthdate : "No DOB"}
                          </span>
                        </div>
                      </Td>

                      {/* Pet Owner */}
                      <Td>
                        {owner ? (
                          <div className="flex flex-col">
                            <span className="font-bold text-xs text-ink">{owner.name}</span>
                            <span className="text-[11px] text-ink-muted truncate max-w-[150px]">{owner.email}</span>
                          </div>
                        ) : (
                          <span className="text-xs text-ink-muted italic">Unassigned</span>
                        )}
                      </Td>

                      {/* Telemetry Collar */}
                      <Td>
                        {assignedDevice ? (
                          <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border border-brand/20 bg-brand-soft/40 text-xs">
                            <Radio size={13} className="text-brand" />
                            <Link
                              to={`/devices?device_code=${assignedDevice.device_code}`}
                              className="font-mono font-bold text-brand hover:underline"
                            >
                              {assignedDevice.device_code}
                            </Link>
                            <button
                              type="button"
                              onClick={() => handleUnpairCollar(assignedDevice, d)}
                              title="Unpair Collar"
                              className="ml-1 text-ink-muted hover:text-high-fg p-0.5"
                            >
                              <Unlink size={12} />
                            </button>
                          </div>
                        ) : (
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            onClick={() => handleOpenPairing(d)}
                            className="text-[11px] h-7 px-2 flex items-center gap-1 text-brand border-dashed border-brand/40"
                          >
                            <Radio size={12} />
                            <span>+ Assign Collar</span>
                          </Button>
                        )}
                      </Td>

                      {/* Actions */}
                      <Td className="text-right pr-4">
                        <div className="flex items-center justify-end gap-1.5">
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            onClick={() => navigate(`/dogs/${d.id}`)}
                            className="h-8 text-xs font-bold"
                          >
                            Live Vitals
                          </Button>
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            onClick={() => handleOpenEdit(d)}
                            className="h-8 w-8 p-0"
                            title="Edit Dog Profile"
                          >
                            <Edit size={14} />
                          </Button>
                        </div>
                      </Td>
                    </Tr>
                  );
                })}
              </TBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* ========================================================================= */}
      {/* MODAL 1: EDIT DOG PROFILE                                                 */}
      {/* ========================================================================= */}
      {editingDog && (
        <Dialog
          title={`Edit Patient: ${editingDog.name}`}
          open={Boolean(editingDog)}
          onClose={() => setEditingDog(null)}
        >
          <form onSubmit={handleSaveEdit} className="flex flex-col gap-4">
            {/* Photo Avatar Preview / Upload */}
            <div className="flex items-center gap-4 p-3 rounded-xl border border-hairline bg-surface-alt/40">
              <div className="h-16 w-16 rounded-xl overflow-hidden bg-brand-soft border border-brand/20 flex items-center justify-center shrink-0">
                {editPhotoPreview ? (
                  <img src={editPhotoPreview} alt="Dog Avatar" className="h-full w-full object-cover" />
                ) : (
                  <PawPrint size={24} className="text-brand" />
                )}
              </div>
              <div className="flex flex-col gap-1.5 flex-1">
                <span className="text-xs font-bold text-ink">Patient Photo</span>
                <div className="flex items-center gap-2">
                  <label className="cursor-pointer inline-flex items-center gap-1.5 text-xs font-bold text-brand bg-white dark:bg-surface border border-brand/30 px-2.5 py-1 rounded-lg hover:bg-brand-soft">
                    <ImageIcon size={13} />
                    <span>Upload New Photo</span>
                    <input type="file" accept="image/*" onChange={handlePhotoChange} className="hidden" />
                  </label>
                  {editPhotoPreview && (
                    <button
                      type="button"
                      onClick={() => {
                        setEditPhotoFile(null);
                        setEditPhotoPreview(null);
                      }}
                      className="text-xs text-high-fg hover:underline font-semibold"
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-name" className="text-xs font-bold text-ink">
                  Patient Name <span className="text-high-fg">*</span>
                </Label>
                <Input
                  id="edit-dog-name"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  required
                />
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-breed" className="text-xs font-bold text-ink">
                  Breed
                </Label>
                <Input
                  id="edit-dog-breed"
                  value={editBreed}
                  onChange={(e) => setEditBreed(e.target.value)}
                  placeholder="e.g. Golden Retriever"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-sex" className="text-xs font-bold text-ink">
                  Biological Sex
                </Label>
                <Select
                  id="edit-dog-sex"
                  value={editSex}
                  onChange={(e) => setEditSex(e.target.value as DogSex)}
                >
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                  <option value="unknown">Unknown</option>
                </Select>
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-weight" className="text-xs font-bold text-ink">
                  Weight (kg)
                </Label>
                <Input
                  id="edit-dog-weight"
                  type="number"
                  step="0.1"
                  value={editWeightKg}
                  onChange={(e) => setEditWeightKg(e.target.value)}
                  placeholder="e.g. 15.4"
                />
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-dob" className="text-xs font-bold text-ink">
                  Birthdate
                </Label>
                <Input
                  id="edit-dog-dob"
                  type="date"
                  value={editBirthdate}
                  onChange={(e) => setEditBirthdate(e.target.value)}
                />
              </div>
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-dog-notes" className="text-xs font-bold text-ink">
                Clinical & Triage Notes
              </Label>
              <textarea
                id="edit-dog-notes"
                value={editNotes}
                onChange={(e) => setEditNotes(e.target.value)}
                rows={3}
                className="rounded-xl border border-hairline bg-surface p-2.5 text-xs text-ink focus:outline-none focus:ring-2 focus:ring-brand/30"
                placeholder="Post-surgery recovery, allergies, behavioral notes..."
              />
            </div>

            <div className="flex justify-end gap-2 pt-3 border-t border-hairline">
              <Button type="button" variant="secondary" onClick={() => setEditingDog(null)} disabled={saving}>
                Cancel
              </Button>
              <Button type="submit" disabled={saving} className="font-bold bg-brand text-white">
                {saving ? "Saving Changes..." : "Save Patient Profile"}
              </Button>
            </div>
          </form>
        </Dialog>
      )}

      {/* ========================================================================= */}
      {/* MODAL 2: PAIR / BIND HARDWARE COLLAR                                      */}
      {/* ========================================================================= */}
      {pairingDog && (
        <Dialog
          title={`Assign Telemetry Collar: ${pairingDog.name}`}
          open={Boolean(pairingDog)}
          onClose={() => setPairingDog(null)}
        >
          <form onSubmit={handleSavePairing} className="flex flex-col gap-4">
            <p className="text-xs text-ink-muted m-0">
              Select an available unassigned collar from your clinic fleet to link real-time biometric telemetry stream to{" "}
              <strong>{pairingDog.name}</strong>.
            </p>

            <div className="flex flex-col gap-2">
              <Label htmlFor="collar-select" className="text-xs font-bold text-ink">
                Available Collar Hardware
              </Label>
              <Select
                id="collar-select"
                value={selectedCollarId}
                onChange={(e) => setSelectedCollarId(e.target.value)}
                required
                className="h-11 font-medium"
              >
                <option value="">— Select an available collar —</option>
                {availableDevices.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.device_code} (FW: {d.firmware_version ?? "0.1.0"})
                  </option>
                ))}
              </Select>
              <p className="text-xs text-ink-muted m-0">
                {availableDevices.length} unassigned collars ready in fleet.
              </p>
            </div>

            <div className="flex justify-end gap-2 pt-3 border-t border-hairline">
              <Button type="button" variant="secondary" onClick={() => setPairingDog(null)} disabled={saving}>
                Cancel
              </Button>
              <Button type="submit" disabled={saving || !selectedCollarId} className="font-bold bg-brand text-white">
                {saving ? "Pairing Collar..." : "Pair Telemetry Collar"}
              </Button>
            </div>
          </form>
        </Dialog>
      )}
    </div>
  );
}
