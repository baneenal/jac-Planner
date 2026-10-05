"""jac-Planner - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return <ClientApp />;
}
