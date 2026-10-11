# ADR-025: Ambient temperature as the sole active environmental feature

Status: Accepted, 2026-10-11, explicitly requested by the project owner.

FurFeel retains ambient temperature and retires humidity from active device
payloads, intake features, rule-v1 scoring, threshold controls, reports, care
context and training exports. The DHT22 remains installed for ambient temperature.
The provisional ambient heat threshold remains unchanged at 32°C by default,
with the existing per-dog override; cold context remains unchanged. This is a
feature-scope decision, not evidence that humidity has no biological relevance
or that ambient temperature establishes fear/anxiety. No clinical cutoff is added.

Historical humidity telemetry and override columns are retained and documented
as deprecated, without deleting or changing historical readings, classifications
or raw_payload. Older firmware may still send humidity: intake ignores it as a
feature and retains the original payload. This supports a staged client rollout.

The stress classifier remains rule-v1. Random Forest requires real synchronized
expert-labeled recordings. New models must omit humidity; historical training
exports must explicitly select the active feature set.

This change is implemented locally; migration and Edge Function deployment are
separate rollout steps. Deploy the ambient-only intake before rolling out new
clients. Build/flash the updated firmware separately. Models are not retrained
automatically, and existing historical classifications are not recomputed.
