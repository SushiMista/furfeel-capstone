import { Link } from "react-router-dom";
import {
  Attachment,
  AttachmentAction,
  AttachmentActions,
  AttachmentContent,
  AttachmentDescription,
  AttachmentMedia,
  AttachmentTitle,
  AttachmentTrigger,
} from "./ui/attachment.tsx";

export function ImageAttachmentNotification({
  dogId,
  dogName,
  imageUrl,
  fileName,
  metaText,
}: {
  dogId: string;
  dogName: string;
  imageUrl: string;
  fileName: string;
  metaText: string;
}) {
  return (
    <Attachment orientation="horizontal" className="border-none p-0 bg-transparent shadow-none w-80">
      <AttachmentMedia variant="image">
        {imageUrl ? (
          <img src={imageUrl} alt={dogName} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full bg-muted flex items-center justify-center text-xs text-ink-muted">
            No img
          </div>
        )}
      </AttachmentMedia>
      <AttachmentContent>
        <AttachmentTitle>{dogName} shared a photo</AttachmentTitle>
        <AttachmentDescription>{fileName} ({metaText})</AttachmentDescription>
      </AttachmentContent>
      <AttachmentActions>
        <AttachmentAction aria-label="Review photo" className="text-brand-strong bg-brand-soft hover:bg-brand hover:text-white px-2 py-1 rounded text-xs font-semibold h-auto w-auto">
          Review
        </AttachmentAction>
      </AttachmentActions>
      <AttachmentTrigger
        render={
          <Link to={`/dogs/${dogId}?tab=review`} />
        }
      />
    </Attachment>
  );
}
