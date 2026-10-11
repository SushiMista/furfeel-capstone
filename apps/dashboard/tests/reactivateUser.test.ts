import {expect, it, vi} from 'vitest';
import type {SupabaseClient} from '@supabase/supabase-js';
import {reactivateUserAccount} from '../src/lib/adminQueries.ts';
it('uses only the reactivation endpoint and verifies its result', async () => {
  const invoke = vi.fn().mockResolvedValue({data:{ok:true,action:'reactivated'},error:null});
  await reactivateUserAccount({functions:{invoke}} as unknown as SupabaseClient, 'user-1');
  expect(invoke).toHaveBeenCalledWith('admin-reactivate-user', {body:{userId:'user-1'}});
  invoke.mockResolvedValue({data:{ok:true,action:'deleted'},error:null});
  await expect(reactivateUserAccount({functions:{invoke}} as unknown as SupabaseClient,'user-1')).rejects.toThrow('did not confirm reactivation');
});
