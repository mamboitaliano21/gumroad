import { useForm, usePage } from "@inertiajs/react";
import * as React from "react";

import { Button } from "$app/components/Button";
import { NavigationButtonInertia } from "$app/components/NavigationButton";
import { Fieldset } from "$app/components/ui/Fieldset";
import { Input } from "$app/components/ui/Input";
import { Label } from "$app/components/ui/Label";
import { PageHeader } from "$app/components/ui/PageHeader";
import { Textarea } from "$app/components/ui/Textarea";

type PageData = {
  id: string;
  title: string;
  permalink: string;
  raw_html: string;
  public_url: string;
};

type Props = {
  page: PageData;
};

export default function PagesEdit() {
  const { page } = usePage<Props>().props;
  const form = useForm({
    page: { title: page.title, raw_html: page.raw_html },
  });

  const handleSubmit = (event?: React.FormEvent<HTMLFormElement>) => {
    event?.preventDefault();
    form.patch(Routes.page_path(page.id));
  };

  return (
    <div>
      <PageHeader
        title="Edit page"
        actions={
          <>
            <NavigationButtonInertia href={Routes.pages_path()} disabled={form.processing}>
              Cancel
            </NavigationButtonInertia>
            <Button color="accent" onClick={() => handleSubmit()} disabled={form.processing}>
              {form.processing ? "Saving…" : "Save changes"}
            </Button>
          </>
        }
      />
      <form onSubmit={handleSubmit} className="grid gap-8 p-4 md:p-8">
        <div className="text-sm text-muted">
          Visible at{" "}
          <a href={page.public_url} target="_blank" rel="noopener noreferrer">
            {page.public_url}
          </a>
        </div>
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
