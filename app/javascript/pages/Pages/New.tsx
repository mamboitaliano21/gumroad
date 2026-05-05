import { useForm } from "@inertiajs/react";
import * as React from "react";

import { Button } from "$app/components/Button";
import { NavigationButtonInertia } from "$app/components/NavigationButton";
import { Fieldset } from "$app/components/ui/Fieldset";
import { Input } from "$app/components/ui/Input";
import { Label } from "$app/components/ui/Label";
import { Textarea } from "$app/components/ui/Textarea";

type PagesNewProps = {
  starter_html: string;
  starter_title: string;
};

export default function PagesNew({ starter_html, starter_title }: PagesNewProps) {
  const form = useForm({
    page: { title: starter_title, raw_html: starter_html },
  });

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post("/pages");
  };

  return (
    <main>
      <header>
        <h1>New page</h1>
        <div className="actions">
          <NavigationButtonInertia href="/pages">Cancel</NavigationButtonInertia>
        </div>
      </header>
      <form onSubmit={handleSubmit}>
        <Fieldset state={form.errors["page.title"] ? "danger" : undefined}>
          <Label htmlFor="page-title">Title</Label>
          <Input
            id="page-title"
            type="text"
            value={form.data.page.title}
            onChange={(e) => form.setData("page", { ...form.data.page, title: e.target.value })}
            required
          />
        </Fieldset>
        <Fieldset state={form.errors["page.raw_html"] ? "danger" : undefined}>
          <Label htmlFor="page-raw-html">HTML</Label>
          <Textarea
            id="page-raw-html"
            rows={20}
            value={form.data.page.raw_html}
            onChange={(e) => form.setData("page", { ...form.data.page, raw_html: e.target.value })}
            required
          />
        </Fieldset>
        <Button type="submit" color="accent" disabled={form.processing}>
          {form.processing ? "Saving…" : "Create page"}
        </Button>
      </form>
    </main>
  );
}
