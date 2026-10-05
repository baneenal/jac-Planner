"""Responsive shared planner and live focus timers."""

import from "react" { useEffect }
import "./planner.styles.css";
sv import from endpoints { AddTask, EditTask, FocusSession, ListSessions, ListTasks, LogSession, RemoveTask, Task, ToggleTask }

# Display timer seconds as a consistent two-digit minute-and-second clock.
def format_time(total_seconds: int) -> str {
    minute_text = ("0" + str(total_seconds // 60))[-2:];
    second_text = ("0" + str(total_seconds % 60))[-2:];
    return minute_text + ":" + second_text;
}

# Keep typed durations within the supported one-to-180-minute range.
def parse_duration_minutes(minutes: str) -> int {
    requested_minutes = int(minutes) if minutes else 1;
    return max(1, min(180, requested_minutes));
}

# Display each task with controls for completion, editing, and removal.
def:pub TaskRow(
    task: Task,
    on_toggle: Callable[[str], None],
    on_edit: Callable[[str, str], None],
    on_remove: Callable[[str], None]
) -> JsxElement {
    has editing: bool = False,
        edit_title: str = "";

    def complete_this_task(_e: MouseEvent) {
        on_toggle(task.task_id);
    }
    def begin_edit(_e: MouseEvent) {
        edit_title = task.title;
        editing = True;
    }
    def cancel_edit(_e: MouseEvent) {
        editing = False;
    }
    def remove_this_task(_e: MouseEvent) {
        on_remove(task.task_id);
    }
    def save_edit(e: FormEvent) {
        e.preventDefault();
        if edit_title.strip() {
            on_edit(task.task_id, edit_title.strip());
            editing = False;
        }
    }

    return <article className={"task-row" + (" task-row-complete" if task.completed else "")}>
        <button
            key="completion"
            className={"task-check" + (" task-check-complete" if task.completed else "")}
            type="button"
            onClick={complete_this_task}
            aria-label={"Mark " + task.title + (" incomplete" if task.completed else " complete")}
            aria-pressed={task.completed}
        >
            {"✓" if task.completed else ""}
        </button>
        <div className="task-main">
            {if editing {
                <form className="task-edit-form" onSubmit={save_edit} key="edit-form">
                    <input
                        className="task-edit-input"
                        type="text"
                        value={edit_title}
                        onChange={lambda (e: ChangeEvent) { edit_title = e.target.value; }}
                        aria-label={"Edit " + task.title}
                        maxLength={120}
                    />
                    <button className="task-edit-save" type="submit">Save</button>
                    <button className="task-edit-cancel" type="button" onClick={cancel_edit}>Cancel</button>
                </form>
            }}
            {if not editing {
                <div className="task-display" key="task-display">
                    <div className="task-copy" key="task-copy">
                        <span className="task-title">{task.title}</span>
                        <span className="task-meta">{task.category}</span>
                    </div>
                    <span className={"priority priority-" + task.priority.lower()} key="task-priority">{task.priority}</span>
                    <button className="task-edit" type="button" onClick={begin_edit} aria-label={"Edit " + task.title} key="task-edit">Edit</button>
                </div>
            }}
        </div>
        <button
            key="remove"
            className="task-remove"
            type="button"
            onClick={remove_this_task}
            aria-label={"Remove " + task.title}
        >×</button>
    </article>;
}

def:pub app -> JsxElement {
    # jac:ignore[W2003]
    has tasks: list[Task] = [],
        sessions: list[FocusSession] = [],
        task_title: str = "",
        adding_task: bool = False,
        task_category: str = "Study",
        task_priority: str = "Normal",
        active_tab: str = "Overview",
        session_type: str = "Focus",
        selected_duration: int = 25,
        focus_remaining: int = 1500,
        focus_running: bool = False,
        focus_end_at: float = 0.0,
        focus_minutes: str = "25",
        break_minutes: str = "5",
        timer_minutes: str = "30",
        timer_remaining: int = 1800,
        timer_running: bool = False,
        timer_end_at: float = 0.0,
        timer_mode: str = "Pomodoro";

    # Load shared tasks and timer history when the planner opens.
    async can with entry {
        load_planner();
    }

    # Keep both countdown displays accurate and release the browser interval on unmount.
    useEffect(lambda {
        interval = setInterval(lambda { update_timers(); }, 1000);
        return lambda { clearInterval(interval); };
    }, [focus_running, focus_end_at, timer_running, timer_end_at]);

    async def load_planner -> None;
    async def add_task(submit_event: FormEvent) -> None;
    async def toggle_task(task_id: str) -> None;
    async def edit_task(task_id: str, title: str) -> None;
    async def remove_task(task_id: str) -> None;
    async def update_timers -> None;
    def open_add_task(_e: MouseEvent) -> None;
    def cancel_add_task(_e: MouseEvent) -> None;
    def choose_focus(_e: MouseEvent) -> None;
    def choose_break_timer(_e: MouseEvent) -> None;
    def edit_focus_minutes(e: ChangeEvent) -> None;
    def edit_break_minutes(e: ChangeEvent) -> None;
    def start_focus(_e: MouseEvent) -> None;
    def pause_focus(_e: MouseEvent) -> None;
    def edit_timer_minutes(e: ChangeEvent) -> None;
    def start_timer(_e: MouseEvent) -> None;
    def pause_timer(_e: MouseEvent) -> None;
    def select_pomodoro(_e: MouseEvent) -> None;
    def select_timer(_e: MouseEvent) -> None;
    def select_overview(_e: MouseEvent) -> None;
    def select_tasks(_e: MouseEvent) -> None;

    # Display the workspace navigation, task controls, and focus-room interface.
    return <div className="planner-shell">
        <aside className="sidebar">
            <a className="wordmark" href="#overview"><span className="wordmark-mark">d.</span> daymark</a>
            <span className="nav-caption">WORKSPACE</span>
            <button className={"nav-link" + (" nav-link-active" if active_tab == "Overview" else "")} onClick={select_overview}>
                <span className="nav-icon">◷</span> Overview
            </button>
            <button className={"nav-link" + (" nav-link-active" if active_tab == "Tasks" else "")} onClick={select_tasks}>
                <span className="nav-icon">☷</span> My tasks
            </button>
            <div className="sidebar-note">
                <span className="sidebar-note-dot" /> YOUR DAY, AT YOUR PACE
            </div>
            <div className="sidebar-profile">
                <span className="avatar">D</span>
                <span className="profile-text"><strong>My planner</strong><small>Personal workspace</small></span>
            </div>
        </aside>

        <main className="planner-main" id="overview">
            <header className="topbar">
                <span className="breadcrumb">Workspace <span>/</span> {active_tab}</span>
                <a className="topbar-date" href="#tasks"><span className="online-dot" /> Planning locally</a>
            </header>

            <section className="welcome-row">
                <div>
                    <span className="eyebrow"><span className="eyebrow-line" /> A LITTLE PROGRESS ADDS UP</span>
                    <h1>My personal plan</h1>
                    <p className="welcome-subtitle">Make room for what matters today.</p>
                </div>
                <a className="text-link" href="#tasks">View your tasks <span>↗</span></a>
            </section>

            <section className="metrics-strip" aria-label="Your planner summary">
                <div className="metric-item"><span className="metric-icon metric-icon-green">◷</span><span><small>IN FOCUS TODAY</small><strong>{str(len([session for session in sessions if session.completed])) + " sessions"}</strong></span></div>
                <span className="metric-divider" />
                <div className="metric-item"><span className="metric-icon metric-icon-coral">☷</span><span><small>LEFT TO DO</small><strong>{str(len([task for task in tasks if not task.completed])) + " tasks"}</strong></span></div>
                <span className="metric-divider" />
                <div className="metric-item"><span className="metric-icon metric-icon-yellow">✓</span><span><small>ALREADY DONE</small><strong>{str(len([task for task in tasks if task.completed])) + " tasks"}</strong></span></div>
            </section>

            <div className="content-grid">
                <section className="tasks-panel" id="tasks">
                    <div className="section-heading">
                        <div><span className="eyebrow">YOUR PERSONAL PLAN</span><h2>My tasks</h2></div>
                        <div className="task-heading-actions">
                            <span className="count-badge">{"Task: #" + str(len(tasks))}</span>
                            <button className="add-button" type="button" onClick={open_add_task}><span>+</span> Add task</button>
                        </div>
                    </div>

                    {if adding_task {
                        <form className="task-form" onSubmit={add_task} key="task-form">
                            <label className="field-label" htmlFor="task-title">ADD A TASK</label>
                            <input id="task-title" className="task-input" type="text" value={task_title} onChange={lambda (e: ChangeEvent) { task_title = e.target.value; }} placeholder="What would you like to do?" maxLength={120} autoFocus />
                            <div className="form-details">
                                <label className="select-wrap"><span className="visually-hidden">Category</span><select className="detail-select" value={task_category} onChange={lambda (e: ChangeEvent) { task_category = e.target.value; }}><option>Study</option><option>Personal</option><option>Work</option></select></label>
                                <label className="select-wrap"><span className="visually-hidden">Priority</span><select className="detail-select" value={task_priority} onChange={lambda (e: ChangeEvent) { task_priority = e.target.value; }}><option>Normal</option><option>High</option><option>Low</option></select></label>
                                <button className="add-button" type="submit">Add task</button>
                                <button className="task-edit-cancel" type="button" onClick={cancel_add_task}>Cancel</button>
                            </div>
                        </form>
                    }}

                    <div className="task-list-heading"><span>YOUR TASKS</span><span>{str(len([task for task in tasks if not task.completed])) + " open"}</span></div>
                    <div className="task-list">
                        {for task in tasks {
                            <TaskRow key={task.task_id} task={task} on_toggle={toggle_task} on_edit={edit_task} on_remove={remove_task}/>
                        }}
                        {if len(tasks) == 0 {
                            <div className="empty-tasks" key="empty-tasks"><span className="empty-mark">✳</span><strong>Your next step goes here.</strong><span>Add a task above to get started.</span></div>
                        }}
                    </div>
                </section>

                <aside className="focus-column" id="focus">
                    <section className="timer-panel">
                        <div className="timer-panel-heading"><div><span className="eyebrow">MAKE SPACE TO FOCUS</span><h2>Focus room</h2></div><span className="timer-flower">✳</span></div>
                        <div className="timer-tabs" role="tablist" aria-label="Choose a timer">
                            <button className={"timer-tab" + (" timer-tab-active" if timer_mode == "Pomodoro" else "")} onClick={select_pomodoro} role="tab">Pomodoro</button>
                            <button className={"timer-tab" + (" timer-tab-active" if timer_mode == "Timer" else "")} onClick={select_timer} role="tab">Timer</button>
                        </div>
                        {if timer_mode == "Pomodoro" {
                            <div className="pomodoro-settings" key="pomodoro-settings">
                                <div className="duration-choices" aria-label="Choose focus or break timer">
                                    <button className={"duration-chip" + (" duration-selected" if session_type == "Focus" else "")} onClick={choose_focus} aria-pressed={session_type == "Focus"} disabled={focus_running}>Focus timer</button>
                                    <button className={"duration-chip" + (" duration-selected" if session_type == "Break" else "")} onClick={choose_break_timer} aria-pressed={session_type == "Break"} disabled={focus_running}>Break timer</button>
                                </div>
                                <div className="duration-inputs">
                                    <label className="custom-duration duration-field">FOCUS MINUTES<input type="number" min="1" max="180" value={focus_minutes} onChange={edit_focus_minutes} disabled={focus_running} aria-label="Focus timer minutes"/></label>
                                    <label className="custom-duration duration-field">BREAK MINUTES<input type="number" min="1" max="180" value={break_minutes} onChange={edit_break_minutes} disabled={focus_running} aria-label="Break timer minutes"/></label>
                                </div>
                            </div>
                        }}
                        {if timer_mode == "Timer" {
                            <label className="custom-duration" key="custom-timer">COUNTDOWN MINUTES<input type="number" min="1" max="180" value={timer_minutes} onChange={edit_timer_minutes}/></label>
                        }}
                        <div className="clock-face">
                            <span className="clock-caption">{("CURRENT SESSION / " + session_type.upper()) if timer_mode == "Pomodoro" else "YOUR OWN COUNTDOWN"}</span>
                            <strong className="clock-digits">{format_time(focus_remaining if timer_mode == "Pomodoro" else timer_remaining)}</strong>
                            <span className="clock-caption clock-hint">{("A softer pace, one " + str(selected_duration) + " minutes at a time") if timer_mode == "Pomodoro" else "Set aside a little time for yourself"}</span>
                        </div>
                        <div className="timer-controls">
                            {if timer_mode == "Pomodoro" {
                                <button className="timer-start" onClick={start_focus} key="pomodoro-start">{"Ⅱ  Pause session" if focus_running else "▶  Start session"}</button>
                            }}
                            {if timer_mode == "Timer" {
                                <button className="timer-start" onClick={start_timer} key="timer-start">{"Ⅱ  Pause timer" if timer_running else "▶  Start timer"}</button>
                            }}
                        </div>
                        <p className="timer-footnote"><span>◉</span> Your focus sessions are saved to your planner.</p>
                    </section>

                    <section className="sessions-panel">
                        <div className="sessions-heading"><h3>Recent focus</h3><span>{str(len(sessions)) + " total"}</span></div>
                        {if len(sessions) == 0 {
                            <p className="sessions-empty" key="sessions-empty">Your finished sessions will show up here.</p>
                        }}
                        {for session in sessions[:4] {
                            <div className="session-row" key={session.session_id}>
                                <span className="session-mark">{"✓" if session.completed else "–"}</span>
                                <span className="session-label">{session.session_type}<small>{session.created_at}</small></span>
                                <strong className="session-time">{str(session.duration_minutes) + " min"}</strong>
                            </div>
                        }}
                    </section>
                </aside>
            </div>

            <footer className="page-footer"><span>DAYMARK <span className="footer-dot">·</span> A little progress adds up.</span><span>Your plan is shared wherever you work.</span></footer>
        </main>

        <div className="mobile-nav" aria-label="Mobile navigation">
            <button className={"mobile-nav-link" + (" mobile-nav-active" if active_tab == "Overview" else "")} onClick={select_overview}><span>◷</span>Overview</button>
            <button className={"mobile-nav-link" + (" mobile-nav-active" if active_tab == "Tasks" else "")} onClick={select_tasks}><span>☷</span>Tasks</button>
            <a className="mobile-nav-link" href="#focus"><span>◎</span>Focus</a>
        </div>
    </div>;
}