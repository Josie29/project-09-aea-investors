/**
 * Upload constraints, stated to the user before they choose a photo.
 *
 * The visible copy is built from the same constants the client-side guard uses, so the
 * limit a user is told is the limit that is applied. The brief still requires
 * server-side validation — this is a courtesy check that keeps an obviously bad file
 * from being sent, not the enforcement point.
 */

export const MAX_UPLOAD_MB = 10;

/** Bytes per megabyte, using the binary megabyte browsers report in `File.size`. */
const BYTES_PER_MB = 1024 * 1024;

export const MAX_UPLOAD_BYTES = MAX_UPLOAD_MB * BYTES_PER_MB;

/** MIME types the file picker accepts. */
export const ACCEPTED_IMAGE_TYPES = ["image/jpeg", "image/png"] as const;

/** Value for the `accept` attribute on the file inputs. */
export const ACCEPT_ATTRIBUTE = ACCEPTED_IMAGE_TYPES.join(",");

const ACCEPTED_TYPES_LABEL = "JPG or PNG";

/** The constraints line shown inside the dropzone. */
export const UPLOAD_CONSTRAINTS_TEXT = `${ACCEPTED_TYPES_LABEL} · up to ${MAX_UPLOAD_MB} MB · both sides not needed`;

/**
 * Checks a chosen file against the stated limits.
 *
 * @param file - the file the user picked.
 * @returns a user-facing reason the file was rejected, or null when it is acceptable.
 */
export function uploadRejectionReason(file: File): string | null {
  const isAcceptedType = (ACCEPTED_IMAGE_TYPES as readonly string[]).includes(file.type);
  if (!isAcceptedType) {
    return `That file isn't a photo we can read. We need ${ACCEPTED_TYPES_LABEL} — most phone cameras produce one of those by default.`;
  }

  if (file.size > MAX_UPLOAD_BYTES) {
    // Rounded up so the number shown is never smaller than the file actually is.
    const sizeMb = Math.ceil(file.size / BYTES_PER_MB);
    return `That photo is about ${sizeMb} MB and we can take up to ${MAX_UPLOAD_MB} MB. A smaller photo works just as well, or you can type your details instead.`;
  }

  return null;
}
