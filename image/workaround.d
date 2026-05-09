#!/bin/ksh

pfexec dtrace -qw -p `pgrep -x syseventd` -n '
pid$target::zpool_relabel_disk:entry
{
        self->hdl = args[0];
        this->name = copyinstr(arg1);
        this->msg = copyinstr(arg2);

        printf("%s(%p, %s, %s)\n", probefunc, self->hdl, this->name, this->msg);
}

syscall::open:entry
/self->hdl != 0 && self->path == 0/
{
        self->path = copyinstr(arg0);
        printf("  ^ device name: %s\n", self->path);
}

pid$target::zpool_relabel_disk:return
/self->hdl != 0 && (this->r = (int)arg1) != 0/
{
        printf("%s(%p) failed with %d\n", probefunc, self->hdl, this->r);

        self->hdl = 0;
        self->path = 0;
}

pid$target::zpool_relabel_disk:return
/self->hdl != 0 && ((int)arg1) == 0/
{
        printf("%s(%p) succeeded!\n", probefunc, self->hdl);

        stop();
        system("dd if=%s of=/dev/null bs=512 count=1; prun %d", self->path,
            pid);

        self->hdl = 0;
        self->path = 0;
}
'

