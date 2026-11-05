/** A dog's age in words from its birth date, like "3 years old". Null when the
 * date is missing or can't be read. */
export function formatDogAge(birthdate: string | null | undefined, now = new Date()): string | null {
  if (!birthdate) return null;
  const born = new Date(`${birthdate.slice(0, 10)}T00:00:00`);
  if (Number.isNaN(born.getTime()) || born > now) return null;

  let months =
    (now.getFullYear() - born.getFullYear()) * 12 + now.getMonth() - born.getMonth();
  if (now.getDate() < born.getDate()) months -= 1;

  if (months < 1) return "Under 1 month old";
  if (months < 12) return `${months} ${months === 1 ? "month" : "months"} old`;
  const years = Math.floor(months / 12);
  return `${years} ${years === 1 ? "year" : "years"} old`;
}
