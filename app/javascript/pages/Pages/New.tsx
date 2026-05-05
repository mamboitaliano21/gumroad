import { useForm } from "@inertiajs/react";
import * as React from "react";

import { Button } from "$app/components/Button";
import { NavigationButtonInertia } from "$app/components/NavigationButton";
import { Fieldset } from "$app/components/ui/Fieldset";
import { Input } from "$app/components/ui/Input";
import { Label } from "$app/components/ui/Label";
import { PageHeader } from "$app/components/ui/PageHeader";
import { Textarea } from "$app/components/ui/Textarea";

type PagesNewProps = {
  starter_html: string;
  starter_title: string;
};

export default function PagesNew({ starter_html, starter_title }: PagesNewProps) {
  const form = useForm({
    page: { title: starter_title, raw_html: starter_html },
  });

  const handleSubmit = (event?: React.FormEvent<HTMLFormElement>) => {
    event?.preventDefault();
    form.post("/pages");
  };

  return (
    <div>
      <PageHeader
        title="New page"
        actions={
          <>
            <NavigationButtonInertia href="/pages" disabled={form.processing}>
              Cancel
            </NavigationButtonInertia>
            <Button color="accent" onClick={() => handleSubmit()} disabled={form.processing}>
              {form.processing ? "Creating…" : "Create page"}
            </Button>
          </>
        }
      />
      <form onSubmit={handleSubmit} className="grid gap-8 p-4 md:p-8">
        <Fieldset state={form.errors["page.title"] ? "danger" : undefined}>
          <Label htmlFor="page-title">Title</Label>
          <Input
            id="page-title"
            type="text"
            placeholder="Title"
            value={form.data.page.title}
            onChange={(e) => form.setData("page", { ...form.data.page, title: e.target.value })}
            required
          />
        </Fieldset>
        <Fieldset state={form.errors["page.raw_html"] ? "danger" : undefined}>
          <Label htmlFor="page-raw-html">HTML</Label>
          <Textarea
            id="page-raw-html"
            rows={10}
            value={form.data.page.raw_html}
            onChange={(e) => form.setData("page", { ...form.data.page, raw_html: e.target.value })}
            required
          />
        </Fieldset>
      </form>
    </div>
  );
}
