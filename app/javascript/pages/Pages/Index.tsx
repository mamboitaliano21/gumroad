import { router } from "@inertiajs/react";
import * as React from "react";

import { Button } from "$app/components/Button";
import { NavigationButtonInertia } from "$app/components/NavigationButton";
import { Placeholder } from "$app/components/ui/Placeholder";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$app/components/ui/Table";

type PageRow = {
  id: number;
  title: string;
  permalink: string;
  public_url: string;
  updated_at: string;
};

type PagesIndexProps = {
  pages: PageRow[];
};

export default function PagesIndex({ pages }: PagesIndexProps) {
  const handleDelete = (id: number) => {
    // eslint-disable-next-line no-alert
    if (!window.confirm("Delete this page?")) return;
    router.delete(`/pages/${id}`);
  };

  return (
    <main>
      <header>
        <h1>Pages</h1>
        <div className="actions">
          <NavigationButtonInertia color="accent" href="/pages/new">
            New page
          </NavigationButtonInertia>
        </div>
      </header>
      <section>
        {pages.length === 0 ? (
          <Placeholder>
            <h2>No pages yet</h2>
            <p>Create your first page to publish a custom HTML/Tailwind layout.</p>
            <NavigationButtonInertia color="accent" href="/pages/new">
              New page
            </NavigationButtonInertia>
          </Placeholder>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Title</TableHead>
                <TableHead>URL</TableHead>
                <TableHead>Updated</TableHead>
                <TableHead aria-label="Actions" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {pages.map((page) => (
                <TableRow key={page.id}>
                  <TableCell>{page.title}</TableCell>
                  <TableCell>
                    <a href={page.public_url} target="_blank" rel="noopener noreferrer">
                      {page.public_url}
                    </a>
                  </TableCell>
                  <TableCell>{new Date(page.updated_at).toLocaleString()}</TableCell>
                  <TableCell>
                    <NavigationButtonInertia href={`/pages/${page.id}/edit`}>Edit</NavigationButtonInertia>
                    <Button onClick={() => handleDelete(page.id)} color="danger">
                      Delete
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </section>
    </main>
  );
}
