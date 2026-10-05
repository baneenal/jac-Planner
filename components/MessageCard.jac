"""A single guestbook message."""

def:pub MessageCard(author: str, text: str) -> JsxElement {
    return <div style={{
        "padding": "0.75rem 1rem",
        "marginBottom": "0.5rem",
        "backgroundColor": "#f8f9fa",
        "border": "1px solid #e9ecef",
        "borderRadius": "8px"
    }}>
        <span style={{"fontWeight": "700"}}>{author}</span>  # jac:ignore[W2001]
        <p style={{"margin": "0.25rem 0 0", "color": "#333"}}>{text}</p>  # jac:ignore[W2001]
    </div>;  # jac:ignore[W2001]
}
