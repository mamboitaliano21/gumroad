import { useForm } from "@inertiajs/react";
import * as React from "react";

import { Button } from "$app/components/Button";
import { NavigationButtonInertia } from "$app/components/NavigationButton";
import { Fieldset } from "$app/components/ui/Fieldset";
import { Input } from "$app/components/ui/Input";
import { Label } from "$app/components/ui/Label";
import { Textarea } from "$app/components/ui/Textarea";

type PageData = {
  id: number;
  title: string;
  permalink: string;
  raw_html: string;
  public_url: string;
};

type PagesEditProps = {
  page: PageData;
};

export default function PagesEdit({ page }: PagesEditProps) {
  const form = useForm({
    page: { title: page.title, raw_html: page.raw_html },
  });

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(`/pages/${page.id}`);
  };

  return (
    <main>
      <header>
        <h1>Edit page</h1>
        <div className="actions">
          <NavigationButtonInertia href={page.public_url} target="_blank" rel="noopener noreferrer">
            View page
          </NavigationButtonInertia>
          <NavigationButtonInertia href="/pages">Back</NavigationButtonInertia>
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
          {form.processing ? "Saving…" : "Save"}
        </Button>
      </form>
    </main>
  );
}
