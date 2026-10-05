"""Persistent server-side tasks and focus-session history."""

import time;

node Task {
    has task_id: str,
        title: str,
        category: str,
        priority: str,
        due_date: str,
        created_date: str,
        completed: bool = False;
}

node FocusSession {
    has session_id: str,
        session_type: str,
        duration_minutes: int,
        completed: bool,
        created_at: str;
}

walker:pub ListTasks {
    has reports: list[Task] = [];

    # Visit every task connected to the persistent project graph.
    can collect_tasks with Root entry {
        visit [-->];
    }

    # Return each saved task to the requesting client.
    can return_task with Task entry {
        report here;
    }
}

walker:pub AddTask {
    has title: str,
        category: str,
        priority: str,
        due_date: str,
        reports: list[Task] = [];

    # Save a task under the shared root so both clients can find it later.
    can save_task with Root entry {
        new_task = Task(
            task_id=str(time.time_ns()),
            title=self.title,
            category=self.category,
            priority=self.priority,
            due_date=self.due_date,
            created_date=time.strftime("%Y-%m-%d")
        );
        here ++> new_task;
        report new_task;
    }
}

walker:pub CompleteTask {
    has task_id: str,
        reports: list[Task] = [];

    # Locate the requested saved task before changing its completion status.
    can find_task with Root entry {
        visit [here-->[?:Task, task_id == self.task_id]];
    }

    # Mark the task complete and return the updated record.
    can complete_task with Task entry {
        here.completed = True;
        report here;
    }
}

walker:pub ToggleTask {
    has task_id: str,
        reports: list[Task] = [];

    can find_task with Root entry {
        visit [here-->[?:Task, task_id == self.task_id]];
    }

    can toggle_task with Task entry {
        here.completed = not here.completed;
        report here;
    }
}

walker:pub EditTask {
    has task_id: str,
        title: str,
        reports: list[Task] = [];

    can find_task with Root entry {
        visit [here-->[?:Task, task_id == self.task_id]];
    }

    can edit_task with Task entry {
        here.title = self.title;
        report here;
    }
}

walker:pub RemoveTask {
    has task_id: str;

    can find_task with Root entry {
        visit [here-->[?:Task, task_id == self.task_id]];
    }

    can remove_task with Task entry {
        del here;
    }
}

walker:pub ListSessions {
    has reports: list[FocusSession] = [];

    # Visit saved focus sessions using the same persistent project graph.
    can collect_sessions with Root entry {
        visit [-->];
    }

    # Return each recorded session to the requesting client.
    can return_session with FocusSession entry {
        report here;
    }
}

walker:pub LogSession {
    has session_type: str,
        duration_minutes: int,
        completed: bool,
        reports: list[FocusSession] = [];

    # Persist a completed or interrupted timer session for both clients.
    can save_session with Root entry {
        new_session = FocusSession(
            session_id=str(time.time_ns()),
            session_type=self.session_type,
            duration_minutes=self.duration_minutes,
            completed=self.completed,
            created_at=time.strftime("%Y-%m-%d %H:%M")
        );
        here ++> new_session;
        report new_session;
    }
}