import { beforeEach, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ManageDogOwners } from '../src/components/ManageDogOwners.tsx';
import type { Dog, User } from '../../../packages/shared/types/index.ts';
vi.mock('../src/lib/supabaseClient.ts', () => ({supabase: {}}));
const fetchAllUsers = vi.fn(), assignDogOwners = vi.fn(), fetchDogOwners = vi.fn();
vi.mock('../src/lib/adminQueries.ts', () => ({fetchAllUsers: (...args: unknown[]) => fetchAllUsers(...args)}));
vi.mock('../src/lib/queries.ts', () => ({assignDogOwners: (...args: unknown[]) => assignDogOwners(...args), fetchDogOwners: (...args: unknown[]) => fetchDogOwners(...args)}));
const existing = {id: 'owner-1', name: 'Existing', email: 'existing@example.com', role: 'owner'} as User;
const additional = {id: 'owner-2', name: 'Additional', email: 'additional@example.com', role: 'owner'} as User;
const dog = {id: 'dog-1', name: 'Joshua Valderama', owner_user_id: existing.id} as Dog;
beforeEach(() => {vi.clearAllMocks(); fetchAllUsers.mockResolvedValue([existing, additional, {id:'vet-1', name:'Vet', role:'veterinarian'}]); assignDogOwners.mockResolvedValue(undefined); fetchDogOwners.mockResolvedValue([existing, additional]);});
it('adds only newly selected owners and refreshes the list', async () => {
  const saved = vi.fn(); const user = userEvent.setup();
  render(<ManageDogOwners dog={dog} owners={[existing]} onClose={vi.fn()} onSaved={saved}/>);
  const checkbox = await screen.findByRole('checkbox');
  expect(screen.getAllByRole('checkbox')).toHaveLength(1);
  await user.click(checkbox); await user.click(screen.getByRole('button', {name: 'Add 1 owner'}));
  await waitFor(() => expect(saved).toHaveBeenCalledWith([existing, additional]));
  expect(assignDogOwners).toHaveBeenCalledWith({}, dog.id, [additional.id]);
});
it('keeps the editor open and reports denied writes', async () => {
  assignDogOwners.mockRejectedValue(new Error('Permission denied'));
  const saved = vi.fn(); const user = userEvent.setup();
  render(<ManageDogOwners dog={dog} owners={[existing]} onClose={vi.fn()} onSaved={saved}/>);
  await user.click(await screen.findByRole('checkbox')); await user.click(screen.getByRole('button', {name:'Add 1 owner'}));
  await screen.findByRole('alert'); expect(saved).not.toHaveBeenCalled();
});

it('shows inactive owner accounts with an explanation and prevents selection', async () => {
  fetchAllUsers.mockResolvedValue([existing, {...additional, is_active: false}]);
  render(<ManageDogOwners dog={dog} owners={[existing]} onClose={vi.fn()} onSaved={vi.fn()}/>);
  const checkbox = await screen.findByRole('checkbox');
  expect(checkbox).toBeDisabled();
  expect(screen.getByText(/Inactive account/)).toBeInTheDocument();
  expect(screen.getByText('additional@example.com')).toBeInTheDocument();
});
