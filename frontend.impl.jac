"""Task, countdown, and session-history implementations for the planner."""

impl app.load_planner -> None {
    # Refresh tasks and sessions from the same persistent server graph.
    task_list_response = root spawn ListTasks();
    session_list_response = root spawn ListSessions();
    tasks = list(reversed(task_list_response.reports));
    sessions = list(reversed(session_list_response.reports));
}

impl app.add_task(submit_event: FormEvent) -> None {
    # Save a validated task, add it to the screen, and reset the form.
    submit_event.preventDefault();
    if not task_title.strip() {
        return;
    }
    add_task_response = root spawn AddTask(
        title=task_title.strip(),
        category=task_category,
        priority=task_priority,
        due_date=""
    );
    tasks = [add_task_response.reports[0]] + tasks;
    task_title = "";
    adding_task = False;
}

impl app.toggle_task(task_id: str) -> None {
    # Toggle one task's checklist state and update the row without reloading.
    toggled_task_response = root spawn ToggleTask(task_id=task_id);
    if len(toggled_task_response.reports) > 0 {
        updated_task: Task = toggled_task_response.reports[0] as Task;
        tasks = [updated_task if task.task_id == task_id else task for task in tasks];
    }
}

impl app.edit_task(task_id: str, title: str) -> None {
    # Persist an edited task title and update its checklist row.
    edited_task_response = root spawn EditTask(task_id=task_id, title=title);
    if len(edited_task_response.reports) > 0 {
        updated_task: Task = edited_task_response.reports[0] as Task;
        tasks = [updated_task if task.task_id == task_id else task for task in tasks];
    }
}

impl app.remove_task(task_id: str) -> None {
    # Delete the saved task first, then remove it from the current checklist.
    root spawn RemoveTask(task_id=task_id);
    tasks = [task for task in tasks if task.task_id != task_id];
}

impl app.open_add_task(_e: MouseEvent) -> None {
    task_title = "";
    adding_task = True;
}

impl app.cancel_add_task(_e: MouseEvent) -> None {
    task_title = "";
    adding_task = False;
}

impl app.update_timers -> None {
    # Derive each displayed countdown from its fixed deadline to avoid timer drift.
    current_time: float = new(Date).getTime() as float;  # jac:ignore[W2001,W1051,E1053,E1030,E1031]

    if focus_running {
        focus_seconds_left = int((focus_end_at - current_time + 999) / 1000);
        if focus_seconds_left <= 0 {
            focus_remaining = 0;
            focus_running = False;
            root spawn LogSession(
                session_type=session_type,
                duration_minutes=selected_duration,
                completed=True
            );
            load_planner();
        } else {
            focus_remaining = int(focus_seconds_left);
        }
    }

    if timer_running {
        timer_seconds_left = int((timer_end_at - current_time + 999) / 1000);
        if timer_seconds_left <= 0 {
            timer_remaining = 0;
            timer_running = False;
            root spawn LogSession(
                session_type="Timer",
                duration_minutes=int(timer_minutes),
                completed=True
            );
            load_planner();
        } else {
            timer_remaining = int(timer_seconds_left);
        }
    }
}

impl app.choose_focus(_e: MouseEvent) -> None {
    # Select the custom focus duration and reset the countdown.
    requested_duration = parse_duration_minutes(focus_minutes);
    focus_running = False;
    session_type = "Focus";
    selected_duration = requested_duration;
    focus_remaining = requested_duration * 60;
}

impl app.choose_break_timer(_e: MouseEvent) -> None {
    # Select the custom break duration and reset the countdown.
    requested_duration = parse_duration_minutes(break_minutes);
    focus_running = False;
    session_type = "Break";
    selected_duration = requested_duration;
    focus_remaining = requested_duration * 60;
}

impl app.edit_focus_minutes(e: ChangeEvent) -> None {
    requested_duration: int = parse_duration_minutes(e.target.value);
    focus_minutes = str(requested_duration) if e.target.value else "";
    if not focus_running and session_type == "Focus" {
        if e.target.value {
            selected_duration = requested_duration;
            focus_remaining = requested_duration * 60;
        } else {
            focus_remaining = 0;
        }
    }
}

impl app.edit_break_minutes(e: ChangeEvent) -> None {
    requested_duration: int = parse_duration_minutes(e.target.value);
    break_minutes = str(requested_duration) if e.target.value else "";
    if not focus_running and session_type == "Break" {
        if e.target.value {
            selected_duration = requested_duration;
            focus_remaining = requested_duration * 60;
        } else {
            focus_remaining = 0;
        }
    }
}

impl app.start_focus(_e: MouseEvent) -> None {
    # Pause an active session, or start the selected custom Pomodoro countdown.
    if focus_running {
        focus_running = False;
        return;
    }
    requested_duration: int = parse_duration_minutes(focus_minutes if session_type == "Focus" else break_minutes);
    duration_seconds: int = focus_remaining if focus_remaining > 0 else requested_duration * 60;
    selected_duration = requested_duration;
    if focus_remaining <= 0 {
        focus_remaining = duration_seconds;
    }
    focus_end_at = (new(Date).getTime() as float) + duration_seconds * 1000;  # jac:ignore[W2001,W1051,E1053,E1030,E1031]
    timer_running = False;
    focus_running = True;
}

impl app.pause_focus(_e: MouseEvent) -> None {
    # Stop the current Pomodoro without marking an unfinished session complete.
    focus_running = False;
}

impl app.edit_timer_minutes(e: ChangeEvent) -> None {
    # Clamp the custom countdown to one to 180 minutes.
    requested_duration: int = parse_duration_minutes(e.target.value);
    timer_minutes = str(requested_duration);
    if not timer_running {
        timer_remaining = requested_duration * 60;
    }
}

impl app.start_timer(_e: MouseEvent) -> None {
    # Pause the custom timer, or start it for the selected number of minutes.
    if timer_running {
        timer_running = False;
        return;
    }
    requested_duration: int = parse_duration_minutes(timer_minutes);
    duration_seconds: int = timer_remaining if timer_remaining > 0 else requested_duration * 60;
    if timer_remaining <= 0 {
        timer_remaining = duration_seconds;
    }
    timer_end_at = (new(Date).getTime() as float) + duration_seconds * 1000;  # jac:ignore[W2001,W1051,E1053,E1030,E1031]
    focus_running = False;
    timer_running = True;
}

impl app.pause_timer(_e: MouseEvent) -> None {
    # Stop the custom countdown while keeping its remaining time on screen.
    timer_running = False;
}

impl app.select_pomodoro(_e: MouseEvent) -> None {
    # Show the three guided Pomodoro durations.
    timer_mode = "Pomodoro";
}

impl app.select_timer(_e: MouseEvent) -> None {
    # Show the custom countdown duration control.
    timer_mode = "Timer";
}

impl app.select_overview(_e: MouseEvent) -> None {
    # Return to the full daily planner from the workspace navigation.
    active_tab = "Overview";
}

impl app.select_tasks(_e: MouseEvent) -> None {
    # Bring the task list into focus from the workspace navigation.
    active_tab = "Tasks";
}