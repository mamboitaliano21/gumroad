import { router } from "@inertiajs/react";
import * as React from "react";

import * as Routes from "$app/utils/routes";

import { Button } from "$app/components/Button";
import { Modal } from "$app/components/Modal";

type Props = {
  open: boolean;
  onClose: () => void;
  subscriptionId: string;
  canBePaused: boolean;
};

export const PauseDeflectionModal = ({ open, onClose, subscriptionId, canBePaused }: Props) => {
  const [submitting, setSubmitting] = React.useState(false);

  const submitPause = (cycles: 1 | 3) => {
    setSubmitting(true);
    router.post(
      Routes.pause_by_user_subscription_path(subscriptionId),
      { cycles },
      { onFinish: () => setSubmitting(false) },
    );
  };

  const submitCancel = () => {
    setSubmitting(true);
    router.post(
      Routes.unsubscribe_by_user_subscription_path(subscriptionId),
      {},
      { onFinish: () => setSubmitting(false) },
    );
  };

  return (
    <Modal
      open={open}
      title="Need a break?"
      onClose={onClose}
      footer={
        <Button color="danger" onClick={submitCancel} disabled={submitting}>
          Cancel anyway
        </Button>
      }
    >
      {canBePaused ? (
        <>
          <p>
            You can pause your membership instead of cancelling. Your access lapses while paused, and the next charge
            happens automatically when the pause ends.
          </p>
          <div className="grid gap-2 sm:flex">
            <Button color="primary" onClick={() => submitPause(1)} disabled={submitting}>
              Pause for 1 month
            </Button>
            <Button color="primary" onClick={() => submitPause(3)} disabled={submitting}>
              Pause for 3 months
            </Button>
          </div>
        </>
      ) : (
        <p>Pause is not available for this membership.</p>
      )}
    </Modal>
  );
};
