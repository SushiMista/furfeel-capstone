import { useCallback, useEffect, useMemo, useState, type FormEvent, type ChangeEvent } from "react";
import { useNavigate } from "react-router-dom";
import {
  Activity,
  ArrowRight,
  Camera,
  CheckCircle2,
  Circle,
  Cpu,
  Dog as DogIcon,
  HeartPulse,
  Info,
  PawPrint,
  Plus,
  Radio,
  Sparkles,
  Upload,
  UserCheck,
  UserPlus,
  Users,
  X,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { useCurrentRole } from "../../lib/useCurrentRole.ts";
import { useToast } from "../../components/ui/toast.tsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Label, Select } from "../../components/ui/input.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { friendlyError } from "../../lib/errors.ts";
import {
  createDog,
  fetchAllDevices,
  fetchAllUsers,
  fetchClinics,
  registerDevice,
  updateDevice,
} from "../../lib/adminQueries.ts";
import { uploadDogPhoto } from "../../lib/queries.ts";
import { seedInitialBiotelemetry } from "../../lib/biotelemetrySeeder.ts";
import type { Clinic, Device, DogSex, User } from "../../../../../packages/shared/types/index.ts";

export function PatientIntake() {
  const navigate = useNavigate();
  const toast = useToast();
  const { session } = useAuth();
  const { role, clinicId: userClinicId } = useCurrentRole();

  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  // Reference data
  const [users, setUsers] = useState<User[]>([]);
  const [clinics, setClinics] = useState<Clinic[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);

  // Form: Dog Info
  const [name, setName] = useState("");
  const [breed, setBreed] = useState("");
  const [sex, setSex] = useState<DogSex>("unknown");
  const [birthdate, setBirthdate] = useState("");
  const [weightKg, setWeightKg] = useState("");
  const [notes, setNotes] = useState("");
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);

  // Form: Clinic & Owner
  const [selectedClinicId, setSelectedClinicId] = useState<string>("");
  const [selectedOwnerId, setSelectedOwnerId] = useState<string>("");
  const [ownerSearch, setOwnerSearch] = useState("");

  // Form: Device Telemetry (Existing vs Build New)
  const [deviceMode, setDeviceMode] = useState<"existing" | "new" | "none">("existing");
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>("");
  const [newDeviceCode, setNewDeviceCode] = useState("");
  const [newDeviceFirmware, setNewDeviceFirmware] = useState("0.1.0");

  // Form: Baselines (Optional)
  const [restingHr, setRestingHr] = useState("");
  const [restingRr, setRestingRr] = useState("");

  // Load reference datasets
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [uList, cList, dList] = await Promise.all([
        fetchAllUsers(supabase).catch(() => [] as User[]),
        fetchClinics(supabase).catch(() => [] as Clinic[]),
        fetchAllDevices(supabase).catch(() => [] as Device[]),
      ]);

      setUsers(uList);
      setClinics(cList);
      setDevices(dList);

      // Auto-set clinic if user has one
      if (userClinicId) {
        setSelectedClinicId(userClinicId);
      } else if (cList.length > 0) {
        setSelectedClinicId(cList[0].id);
      }
    } catch (err) {
      toast("error", friendlyError(err, "load intake options"));
    } finally {
      setLoading(false);
    }
  }, [userClinicId, toast]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Filter owners
  const owners = useMemo(() => {
    return users.filter((u) => u.role === "owner" || !u.role);
  }, [users]);

  const filteredOwners = useMemo(() => {
    if (!ownerSearch.trim()) return owners;
    const q = ownerSearch.toLowerCase();
    return owners.filter(
      (o) => o.name.toLowerCase().includes(q) || (o.email && o.email.toLowerCase().includes(q)),
    );
  }, [owners, ownerSearch]);

  // Unassigned devices available for binding
  const availableDevices = useMemo(() => {
    return devices.filter((d) => !d.dog_id && d.status !== "maintenance");
  }, [devices]);

  const selectedOwner = useMemo(() => {
    return users.find((u) => u.id === selectedOwnerId) || null;
  }, [users, selectedOwnerId]);

  const selectedDevice = useMemo(() => {
    return devices.find((d) => d.id === selectedDeviceId) || null;
  }, [devices, selectedDeviceId]);

  // Handle Photo selection
  function handlePhotoChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhotoFile(file);
    const url = URL.createObjectURL(file);
    setPhotoPreview(url);
  }

  function removePhoto() {
    setPhotoFile(null);
    if (photoPreview) {
      URL.revokeObjectURL(photoPreview);
      setPhotoPreview(null);
    }
  }

  // Submit Intake Form
  async function handleSubmit(e: FormEvent) {
    e.preventDefault();

    if (!name.trim()) {
      toast("error", "Please enter the patient dog's name.");
      return;
    }

    if (!selectedOwnerId) {
      toast("error", "Please select a registered Pet Owner for this patient.");
      return;
    }

    setSubmitting(true);
    try {
      // 1. Create Dog Profile
      const dog = await createDog(supabase, {
        name: name.trim(),
        breed: breed.trim() || null,
        sex: sex || "unknown",
        birthdate: birthdate || null,
        weight_kg: weightKg ? parseFloat(weightKg) : null,
        notes: notes.trim() || null,
        owner_user_id: selectedOwnerId,
        clinic_id: selectedClinicId || userClinicId || null,
      });

      // 2. Upload photo if provided
      if (photoFile) {
        try {
          await uploadDogPhoto(supabase, dog.id, photoFile);
        } catch (photoErr) {
          console.warn("Photo upload warning:", photoErr);
        }
      }

      // 3. Device Binding / Creation
      let boundDeviceId: string | null = null;
      if (deviceMode === "new" && newDeviceCode.trim()) {
        // Build & Register New Hardware Collar
        const newDevice = await registerDevice(
          supabase,
          newDeviceCode.trim().toUpperCase(),
          newDeviceFirmware.trim() || "0.1.0",
        );
        boundDeviceId = newDevice.id;
        // Bind to newly created dog
        await updateDevice(supabase, newDevice.id, {
          dog_id: dog.id,
          status: "active",
        });
        toast("success", `Built & paired Collar ${newDevice.device_code} with ${dog.name}`);
      } else if (deviceMode === "existing" && selectedDeviceId) {
        boundDeviceId = selectedDeviceId;
        // Bind existing fleet device
        await updateDevice(supabase, selectedDeviceId, {
          dog_id: dog.id,
          status: "active",
        });
        toast("success", `Paired collar with ${dog.name}`);
      }

      // Seed initial biotelemetry & stress data if device is paired
      if (boundDeviceId) {
        await seedInitialBiotelemetry(supabase, {
          dogId: dog.id,
          deviceId: boundDeviceId,
          baselineHr: restingHr ? parseInt(restingHr, 10) : 85,
          baselineRr: restingRr ? parseInt(restingRr, 10) : 20,
          count: 6,
        });
      }

      // 4. Baseline Configuration if provided
      if (restingHr || restingRr) {
        try {
          await supabase.from("dog_baselines").insert({
            dog_id: dog.id,
            resting_heart_rate_bpm: restingHr ? parseInt(restingHr, 10) : null,
            resting_respiratory_rate_bpm: restingRr ? parseInt(restingRr, 10) : null,
          });
        } catch (baselineErr) {
          console.warn("Baseline save warning:", baselineErr);
        }
      }

      toast("success", `Patient ${dog.name} successfully admitted!`);
      // Redirect directly to Dog Detail telemetry
      navigate(`/dogs/${dog.id}`);
    } catch (err) {
      toast("error", friendlyError(err, "admit patient"));
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <div className="flex flex-col gap-6 max-w-4xl mx-auto py-6">
        <CardSkeleton />
        <CardSkeleton />
      </div>
    );
  }

  const step1Complete = Boolean(name.trim());
  const step2Complete = Boolean(selectedOwnerId);
  const step3Complete =
    deviceMode === "none" ||
    (deviceMode === "existing" && Boolean(selectedDeviceId)) ||
    (deviceMode === "new" && Boolean(newDeviceCode.trim()));
  const step4Complete = Boolean(restingHr || restingRr);
  const isFormReady = step1Complete && step2Complete;

  return (
    <div className="flex flex-col gap-6 max-w-6xl mx-auto py-4">
      {/* Top Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-hairline pb-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand/10 text-brand border border-brand/20 shadow-xs">
              <PawPrint size={22} />
            </div>
            <div>
              <h1 className="m-0 text-2xl font-black text-ink tracking-tight">
                Patient Intake & Admission
              </h1>
              <p className="m-0 mt-0.5 text-xs text-ink-muted">
                Complete clinical admission, link telemetry collar hardware, and associate pet owner account.
              </p>
            </div>
          </div>
        </div>
        <Button variant="secondary" onClick={() => navigate("/board")}>
          View Active Board
        </Button>
      </div>

      <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* ========================================================================= */}
        {/* LEFT COLUMN: 4-STEP INTAKE WORKFLOW                                       */}
        {/* ========================================================================= */}
        <div className="lg:col-span-7 flex flex-col gap-5">
          {/* STEP 1: DOG PROFILE */}
          <Card className="border-hairline shadow-xs">
            <CardHeader className="pb-3 border-b border-hairline/60 bg-surface-alt/30">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand text-white text-xs font-bold">
                    1
                  </span>
                  <CardTitle className="text-base font-bold text-ink">Canine Patient Profile</CardTitle>
                </div>
                {step1Complete && (
                  <span className="inline-flex items-center gap-1 text-xs font-semibold text-calm-fg bg-calm-soft px-2 py-0.5 rounded-full">
                    <CheckCircle2 size={13} /> Complete
                  </span>
                )}
              </div>
              <CardDescription>Primary identification, breed, physiological characteristics, and photo.</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4 pt-4">
              {/* Photo Picker */}
              <div className="flex items-center gap-4 p-3 rounded-lg border border-hairline bg-surface-alt/40">
                <div className="relative flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-xl border-2 border-dashed border-hairline bg-surface shadow-xs">
                  {photoPreview ? (
                    <img src={photoPreview} alt="Dog Avatar Preview" className="h-full w-full object-cover" />
                  ) : (
                    <Camera size={26} className="text-ink-muted/70" />
                  )}
                </div>
                <div className="flex flex-col gap-1.5 flex-1">
                  <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
                    Patient Photo (Optional)
                  </span>
                  <div className="flex items-center gap-2">
                    <label className="cursor-pointer inline-flex items-center gap-1.5 rounded-md border border-hairline bg-surface px-3 py-1.5 text-xs font-semibold text-ink shadow-xs hover:bg-surface-alt transition-colors">
                      <Upload size={14} className="text-brand" />
                      <span>{photoPreview ? "Change Photo" : "Upload Picture"}</span>
                      <input
                        id="dog-photo"
                        type="file"
                        accept="image/*"
                        onChange={handlePhotoChange}
                        className="hidden"
                      />
                    </label>
                    {photoPreview && (
                      <button
                        type="button"
                        onClick={removePhoto}
                        className="inline-flex items-center gap-1 text-xs font-semibold text-high-fg hover:underline px-2 py-1"
                      >
                        <X size={13} /> Remove
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Name & Breed */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="dog-name" className="text-xs font-bold text-ink">
                    Patient Name <span className="text-high-fg">*</span>
                  </Label>
                  <Input
                    id="dog-name"
                    placeholder="e.g. Buddy, Max, Bella"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="dog-breed" className="text-xs font-bold text-ink">Breed</Label>
                  <Input
                    id="dog-breed"
                    placeholder="e.g. Aspin, Golden Retriever, Beagle"
                    value={breed}
                    onChange={(e) => setBreed(e.target.value)}
                  />
                </div>
              </div>

              {/* Sex, Weight, Birthdate */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="dog-sex" className="text-xs font-bold text-ink">Biological Sex</Label>
                  <Select
                    id="dog-sex"
                    value={sex}
                    onChange={(e) => setSex(e.target.value as DogSex)}
                  >
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                    <option value="unknown">Unknown</option>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="dog-weight" className="text-xs font-bold text-ink">Weight (kg)</Label>
                  <Input
                    id="dog-weight"
                    type="number"
                    step="0.1"
                    placeholder="e.g. 14.5"
                    value={weightKg}
                    onChange={(e) => setWeightKg(e.target.value)}
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="dog-birthdate" className="text-xs font-bold text-ink">Birthdate / Est.</Label>
                  <Input
                    id="dog-birthdate"
                    type="date"
                    value={birthdate}
                    onChange={(e) => setBirthdate(e.target.value)}
                  />
                </div>
              </div>

              {/* Clinical Admission Notes */}
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="dog-notes" className="text-xs font-bold text-ink">Clinical Admission & Triage Notes</Label>
                <textarea
                  id="dog-notes"
                  rows={2}
                  className="w-full rounded-md border border-hairline bg-surface px-3 py-2 text-sm text-ink placeholder:text-ink-muted/60 focus:outline-hidden focus:ring-2 focus:ring-brand"
                  placeholder="e.g. Post-operative observation, mild dehydration, calm temperament..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                />
              </div>
            </CardContent>
          </Card>

          {/* STEP 2: WHO IS THE OWNER */}
          <Card className="border-hairline shadow-xs">
            <CardHeader className="pb-3 border-b border-hairline/60 bg-surface-alt/30">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand text-white text-xs font-bold">
                    2
                  </span>
                  <CardTitle className="text-base font-bold text-ink">Who is the Owner?</CardTitle>
                </div>
                {step2Complete && (
                  <span className="inline-flex items-center gap-1 text-xs font-semibold text-calm-fg bg-calm-soft px-2 py-0.5 rounded-full">
                    <CheckCircle2 size={13} /> Linked
                  </span>
                )}
              </div>
              <CardDescription>Associate this patient with their registered pet owner account for mobile app live sync.</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4 pt-4">
              {role === "admin" && (
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="intake-clinic" className="text-xs font-bold text-ink">Admitting Clinic</Label>
                  <Select
                    id="intake-clinic"
                    value={selectedClinicId}
                    onChange={(e) => setSelectedClinicId(e.target.value)}
                  >
                    {clinics.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </Select>
                </div>
              )}

              <div className="flex flex-col gap-1.5">
                <Label htmlFor="owner-search" className="text-xs font-bold text-ink">
                  Search Registered Pet Owner <span className="text-high-fg">*</span>
                </Label>
                <Input
                  id="owner-search"
                  placeholder="Type name or email to filter..."
                  value={ownerSearch}
                  onChange={(e) => setOwnerSearch(e.target.value)}
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <Select
                  id="owner-select"
                  value={selectedOwnerId}
                  onChange={(e) => setSelectedOwnerId(e.target.value)}
                  required
                  className="h-11 font-medium"
                >
                  <option value="">— Select Owner Account —</option>
                  {filteredOwners.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.name} ({o.email})
                    </option>
                  ))}
                </Select>
                <p className="text-xs text-ink-muted m-0">
                  {owners.length} registered owner accounts available.
                </p>
              </div>

              {selectedOwner && (
                <div className="flex items-center gap-3 p-3 rounded-lg border border-brand/25 bg-brand-soft/20 text-xs text-ink">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand text-white font-bold shrink-0">
                    {selectedOwner.name.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex flex-col flex-1">
                    <span className="font-bold text-ink">{selectedOwner.name}</span>
                    <span className="text-ink-muted">{selectedOwner.email}</span>
                  </div>
                  <span className="inline-flex items-center gap-1 font-semibold text-brand text-[11px] bg-white dark:bg-surface px-2 py-0.5 rounded-md border border-brand/20">
                    <UserCheck size={12} /> Verified Owner
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          {/* STEP 3: DEVICE CREATION OR AVAILABLE DEVICE */}
          <Card className="border-hairline shadow-xs">
            <CardHeader className="pb-3 border-b border-hairline/60 bg-surface-alt/30">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand text-white text-xs font-bold">
                    3
                  </span>
                  <CardTitle className="text-base font-bold text-ink">Device Telemetry Hardware</CardTitle>
                </div>
                {step3Complete && (
                  <span className="inline-flex items-center gap-1 text-xs font-semibold text-calm-fg bg-calm-soft px-2 py-0.5 rounded-full">
                    <CheckCircle2 size={13} /> {deviceMode === "none" ? "Deferred" : "Configured"}
                  </span>
                )}
              </div>
              <CardDescription>Choose an available collar from fleet, build/register a new collar, or pair later.</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4 pt-4">
              {/* Segmented Mode Selector */}
              <div className="grid grid-cols-3 gap-1 rounded-xl border border-hairline bg-surface-alt p-1 text-xs font-bold">
                <button
                  type="button"
                  onClick={() => setDeviceMode("existing")}
                  className={`py-2 rounded-lg transition-all flex items-center justify-center gap-1.5 ${
                    deviceMode === "existing"
                      ? "bg-surface shadow-xs text-brand border border-hairline font-extrabold"
                      : "text-ink-muted hover:text-ink"
                  }`}
                >
                  <Radio size={14} />
                  <span>Available Fleet</span>
                </button>
                <button
                  type="button"
                  onClick={() => setDeviceMode("new")}
                  className={`py-2 rounded-lg transition-all flex items-center justify-center gap-1.5 ${
                    deviceMode === "new"
                      ? "bg-surface shadow-xs text-brand border border-hairline font-extrabold"
                      : "text-ink-muted hover:text-ink"
                  }`}
                >
                  <Sparkles size={14} />
                  <span>+ Build New Collar</span>
                </button>
                <button
                  type="button"
                  onClick={() => setDeviceMode("none")}
                  className={`py-2 rounded-lg transition-all flex items-center justify-center gap-1.5 ${
                    deviceMode === "none"
                      ? "bg-surface shadow-xs text-ink border border-hairline font-extrabold"
                      : "text-ink-muted hover:text-ink"
                  }`}
                >
                  <Cpu size={14} />
                  <span>Pair Later</span>
                </button>
              </div>

              {/* Mode 1: Select Available Fleet Collar */}
              {deviceMode === "existing" && (
                <div className="flex flex-col gap-2 pt-1">
                  <Label htmlFor="device-select" className="text-xs font-bold text-ink">
                    Select Available Unassigned Collar
                  </Label>
                  <Select
                    id="device-select"
                    value={selectedDeviceId}
                    onChange={(e) => setSelectedDeviceId(e.target.value)}
                    className="h-11 font-medium"
                  >
                    <option value="">— Choose an unassigned collar —</option>
                    {availableDevices.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.device_code} (Status: {d.status} · FW: {d.firmware_version ?? "0.1.0"})
                      </option>
                    ))}
                  </Select>
                  <p className="text-xs text-ink-muted m-0">
                    {availableDevices.length} unassigned collars ready in fleet inventory.
                  </p>
                </div>
              )}

              {/* Mode 2: Build / Register New Device On-The-Fly */}
              {deviceMode === "new" && (
                <div className="flex flex-col gap-3 rounded-xl border border-brand/30 bg-brand-soft/30 p-4">
                  <div className="flex items-center gap-2 text-xs font-black text-brand">
                    <Sparkles size={15} />
                    <span>Build & Register New Hardware Device</span>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div className="flex flex-col gap-1">
                      <Label htmlFor="new-device-code" className="text-xs font-bold text-ink">
                        Collar Device Code <span className="text-high-fg">*</span>
                      </Label>
                      <Input
                        id="new-device-code"
                        placeholder="e.g. FF-DEV-008"
                        value={newDeviceCode}
                        onChange={(e) => setNewDeviceCode(e.target.value.toUpperCase())}
                        required={deviceMode === "new"}
                        className="font-mono uppercase font-bold"
                      />
                    </div>
                    <div className="flex flex-col gap-1">
                      <Label htmlFor="new-device-fw" className="text-xs font-bold text-ink">
                        Firmware Version
                      </Label>
                      <Input
                        id="new-device-fw"
                        placeholder="0.1.0"
                        value={newDeviceFirmware}
                        onChange={(e) => setNewDeviceFirmware(e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              )}

              {/* Mode 3: Pair Later */}
              {deviceMode === "none" && (
                <div className="flex items-center gap-2.5 p-3 rounded-lg bg-surface-alt text-xs text-ink-muted border border-hairline">
                  <Info size={16} className="text-brand shrink-0" />
                  <span>
                    The patient will be admitted without live telemetry. You can attach a telemetry collar later in the Devices or Patient Detail screen.
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          {/* STEP 4: OPTIONAL BASELINE */}
          <Card className="border-hairline shadow-xs">
            <CardHeader className="pb-3 border-b border-hairline/60 bg-surface-alt/30">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand/30 text-ink text-xs font-bold">
                    4
                  </span>
                  <CardTitle className="text-base font-bold text-ink">Optional Resting Baselines</CardTitle>
                </div>
                {step4Complete ? (
                  <span className="inline-flex items-center gap-1 text-xs font-semibold text-calm-fg bg-calm-soft px-2 py-0.5 rounded-full">
                    <CheckCircle2 size={13} /> Configured
                  </span>
                ) : (
                  <span className="text-xs text-ink-muted font-medium">Optional</span>
                )}
              </div>
              <CardDescription>
                Calibrate custom baseline resting vitals for this dog. The AI model falls back to clinical defaults if omitted.
              </CardDescription>
            </CardHeader>
            <CardContent className="pt-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="resting-hr" className="text-xs font-bold text-ink">Resting Heart Rate (BPM)</Label>
                  <Input
                    id="resting-hr"
                    type="number"
                    placeholder="e.g. 75"
                    value={restingHr}
                    onChange={(e) => setRestingHr(e.target.value)}
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="resting-rr" className="text-xs font-bold text-ink">Resting Resp Rate (BrPM)</Label>
                  <Input
                    id="resting-rr"
                    type="number"
                    placeholder="e.g. 22"
                    value={restingRr}
                    onChange={(e) => setRestingRr(e.target.value)}
                  />
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* ========================================================================= */}
        {/* RIGHT COLUMN: REAL-TIME ADMISSION SUMMARY & STATUS CARD (STICKY)          */}
        {/* ========================================================================= */}
        <div className="lg:col-span-5 lg:sticky lg:top-6 flex flex-col gap-4">
          <Card className="border-brand/30 shadow-md overflow-hidden bg-surface">
            {/* Passport Banner */}
            <div className="bg-gradient-to-r from-brand to-brand-strong p-4 text-white">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <PawPrint size={18} />
                  <span className="font-extrabold text-sm tracking-wide uppercase">Patient Admission Status</span>
                </div>
                <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-white/20">
                  {isFormReady ? "Ready to Admit" : "Drafting..."}
                </span>
              </div>
            </div>

            <CardContent className="p-5 flex flex-col gap-5">
              {/* Live Patient Passport Visual Preview */}
              <div className="flex items-center gap-4 p-4 rounded-xl border border-hairline bg-surface-alt/40 shadow-xs">
                <div className="h-16 w-16 rounded-xl overflow-hidden bg-brand-soft border border-brand/20 flex items-center justify-center shrink-0 shadow-xs">
                  {photoPreview ? (
                    <img src={photoPreview} alt="Dog Avatar" className="h-full w-full object-cover" />
                  ) : (
                    <DogIcon size={30} className="text-brand" />
                  )}
                </div>
                <div className="flex flex-col flex-1 min-w-0">
                  <span className="text-lg font-black text-ink truncate">
                    {name.trim() || "Unnamed Patient"}
                  </span>
                  <div className="flex items-center gap-2 text-xs text-ink-muted mt-0.5">
                    <span>{breed.trim() || "Breed: unspecified"}</span>
                    <span>•</span>
                    <span className="capitalize">{sex}</span>
                    {weightKg && (
                      <>
                        <span>•</span>
                        <span>{weightKg} kg</span>
                      </>
                    )}
                  </div>
                </div>
              </div>

              {/* Admission Checklist Progress Tracker */}
              <div className="flex flex-col gap-2.5">
                <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
                  Intake Completion Checklist
                </span>

                <div className="flex flex-col gap-2 rounded-xl border border-hairline bg-surface-alt/20 p-3">
                  {/* Item 1 */}
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      {step1Complete ? (
                        <CheckCircle2 size={16} className="text-calm-fg shrink-0" />
                      ) : (
                        <Circle size={16} className="text-ink-muted/50 shrink-0" />
                      )}
                      <span className={`font-semibold ${step1Complete ? "text-ink" : "text-ink-muted"}`}>
                        1. Canine Profile
                      </span>
                    </div>
                    <span className="text-xs text-ink-muted font-medium">
                      {step1Complete ? name : "Required"}
                    </span>
                  </div>

                  {/* Item 2 */}
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      {step2Complete ? (
                        <CheckCircle2 size={16} className="text-calm-fg shrink-0" />
                      ) : (
                        <Circle size={16} className="text-ink-muted/50 shrink-0" />
                      )}
                      <span className={`font-semibold ${step2Complete ? "text-ink" : "text-ink-muted"}`}>
                        2. Pet Owner
                      </span>
                    </div>
                    <span className="text-xs text-ink-muted font-medium truncate max-w-[150px]">
                      {selectedOwner ? selectedOwner.name : "Required"}
                    </span>
                  </div>

                  {/* Item 3 */}
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      {step3Complete ? (
                        <CheckCircle2 size={16} className="text-calm-fg shrink-0" />
                      ) : (
                        <Circle size={16} className="text-ink-muted/50 shrink-0" />
                      )}
                      <span className={`font-semibold ${step3Complete ? "text-ink" : "text-ink-muted"}`}>
                        3. Collar Telemetry
                      </span>
                    </div>
                    <span className="text-xs text-ink-muted font-medium">
                      {deviceMode === "new"
                        ? newDeviceCode.trim() || "Code required"
                        : deviceMode === "existing"
                          ? selectedDevice?.device_code || "Select device"
                          : "Pair Later"}
                    </span>
                  </div>

                  {/* Item 4 */}
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      {step4Complete ? (
                        <CheckCircle2 size={16} className="text-calm-fg shrink-0" />
                      ) : (
                        <Circle size={16} className="text-ink-muted/50 shrink-0" />
                      )}
                      <span className={`font-semibold ${step4Complete ? "text-ink" : "text-ink-muted"}`}>
                        4. Resting Baselines
                      </span>
                    </div>
                    <span className="text-xs text-ink-muted font-medium">
                      {step4Complete ? `${restingHr || "—"} BPM / ${restingRr || "—"} RR` : "Default"}
                    </span>
                  </div>
                </div>
              </div>

              {/* Telemetry Hardware Link Status Box */}
              <div className="flex items-center gap-3 p-3 rounded-lg border border-hairline bg-surface-alt/40 text-xs">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-soft text-brand shrink-0">
                  <Radio size={16} />
                </div>
                <div className="flex flex-col flex-1">
                  <span className="font-bold text-ink">Telemetry Stream Target</span>
                  <span className="text-ink-muted text-[11px]">
                    {deviceMode === "new"
                      ? `New Device: ${newDeviceCode || "Pending Code"}`
                      : deviceMode === "existing"
                        ? selectedDevice ? `Fleet Device: ${selectedDevice.device_code}` : "No fleet device selected"
                        : "No device assigned yet"}
                  </span>
                </div>
              </div>

              {/* Action Button */}
              <div className="flex flex-col gap-2 pt-2">
                <Button
                  type="submit"
                  size="lg"
                  disabled={submitting || !isFormReady}
                  className="w-full flex items-center justify-center gap-2 font-black shadow-md h-12 text-sm uppercase tracking-wide"
                >
                  {submitting ? (
                    "Admitting Patient…"
                  ) : (
                    <>
                      <span>Admit Patient & Start Telemetry</span>
                      <ArrowRight size={18} />
                    </>
                  )}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => navigate("/board")}
                  disabled={submitting}
                >
                  Cancel & Exit
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </form>
    </div>
  );
}
