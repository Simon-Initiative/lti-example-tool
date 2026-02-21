import { useEffect, useState } from "react";

type UserDetails = {
  sub: string;
  name: string;
  email: string;
  issuer: string;
  audience: string;
  roles: string;
  context_title: string;
};

type LoadState =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "ready"; user: UserDetails };

export function App() {
  const [state, setState] = useState<LoadState>({ kind: "loading" });

  useEffect(() => {
    const controller = new AbortController();

    async function loadUserDetails() {
      try {
        const response = await fetch("/api/me", {
          method: "GET",
          credentials: "include",
          signal: controller.signal,
          headers: { Accept: "application/json" },
        });

        if (!response.ok) {
          throw new Error(
            response.status === 401
              ? "You are not authenticated for this launch session."
              : `Request failed with status ${response.status}`,
          );
        }

        const user = (await response.json()) as UserDetails;
        setState({ kind: "ready", user });
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }

        const message =
          error instanceof Error ? error.message : "Unknown request error";
        setState({ kind: "error", message });
      }
    }

    void loadUserDetails();

    return () => {
      controller.abort();
    };
  }, []);

  return (
    <main className="mx-auto max-w-3xl px-4 py-8">
      <section className="rounded-lg border border-gray-300 bg-white p-6 shadow-sm">
        <h2 className="text-xl font-semibold text-gray-900">Launch Successful</h2>
        <p className="mt-2 text-sm text-gray-600">
          This view is rendered by a React client and authenticated with launch
          cookies.
        </p>

        {state.kind === "loading" ? (
          <p className="mt-6 text-sm text-gray-600">Loading user details...</p>
        ) : null}

        {state.kind === "error" ? (
          <p className="mt-6 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {state.message}
          </p>
        ) : null}

        {state.kind === "ready" ? (
          <dl className="mt-6 grid gap-3 text-sm">
            <Detail label="User ID" value={state.user.sub} />
            <Detail label="Name" value={state.user.name} />
            <Detail label="Email" value={state.user.email} />
            <Detail label="Roles" value={state.user.roles} />
            <Detail label="Context" value={state.user.context_title} />
            <Detail label="Issuer" value={state.user.issuer} />
            <Detail label="Audience" value={state.user.audience} />
          </dl>
        ) : null}
      </section>
    </main>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid gap-1 border-b border-gray-100 pb-3 sm:grid-cols-[9rem_1fr] sm:gap-3">
      <dt className="font-medium text-gray-700">{label}</dt>
      <dd className="break-all text-gray-900">{value.length > 0 ? value : "-"}</dd>
    </div>
  );
}
