/** vet_notes row shape (docs/09 Database Schema). Staff/vets write, owner + clinic read. */
export interface VetNote {
  id: string;
  dog_id: string;
  author_user_id: string;
  note: string;
  created_at: string;
}
