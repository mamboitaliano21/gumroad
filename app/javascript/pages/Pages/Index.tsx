import { DotsHorizontalRounded, Pencil, Trash } from "@boxicons/react";
import { router } from "@inertiajs/react";
import { formatDistanceToNow } from "date-fns";
import * as React from "react";

import { Button } from "$app/components/Button";
import { NavigationButtonInertia } from "$app/components/NavigationButton";
import { Popover, PopoverContent, PopoverTrigger } from "$app/components/Popover";
import { Menu, MenuItem } from "$app/components/ui/Menu";
import { PageHeader } from "$app/components/ui/PageHeader";
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
  const [openPopoverId, setOpenPopoverId] = React.useState<number | null>(null);

  const handleDelete = (id: number) => {
    setOpenPopoverId(null);
    router.delete(`/pages/${id}`);
  };

  return (
    <div>
      <PageHeader
        title="Pages"
        actions={
          <NavigationButtonInertia color="accent" href="/pages/new">
            New page
          </NavigationButtonInertia>
        }
      />
      <div className="p-4 md:p-8">
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
              {pages.map((row) => (
                <TableRow key={row.id}>
                  <TableCell>{row.title.trim() === "" ? "Untitled" : row.title}</TableCell>
                  <TableCell>
                    <a href={row.public_url} target="_blank" rel="noopener noreferrer">
                      {row.public_url}
                    </a>
                  </TableCell>
                  <TableCell className="whitespace-nowrap">{formatDistanceToNow(row.updated_at)} ago</TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-3 lg:justify-end">
                      <NavigationButtonInertia href={`/pages/${row.id}/edit`} size="icon" aria-label="Edit">
                        <Pencil className="size-5" />
                      </NavigationButtonInertia>
                      <Popover
                        open={openPopoverId === row.id}
                        onOpenChange={(open) => setOpenPopoverId(open ? row.id : null)}
                      >
                        <PopoverTrigger asChild>
                          <Button size="icon" aria-label="Open page action menu">
                            <DotsHorizontalRounded className="size-5" />
                          </Button>
                        </PopoverTrigger>
                        <PopoverContent sideOffset={4} className="border-0 p-0 shadow-none" usePortal>
                          <Menu>
                            <MenuItem variant="danger" onClick={() => handleDelete(row.id)}>
                              <Trash className="size-5" />
                              Delete
                            </MenuItem>
                          </Menu>
                        </PopoverContent>
                      </Popover>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </div>
    </div>
  );
}
