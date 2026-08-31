#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define PERLIO_NOT_STDIO 0
#include <perlio.h>

#include <minijinja.h>

#define THISSvOK(sv) (sv != NULL && SvROK(sv) && SvOK(SvRV(sv)) && INT2PTR(void *, SvIV(SvRV(sv))) != NULL)
#define THIS(sv)   INT2PTR(void *, SvIV(SvRV(sv)))

MODULE = Minijinja      PACKAGE = Minijinja     PREFIX = M_

VERSIONCHECK: DISABLE
PROTOTYPES: DISABLE

BOOT:
{
}

void M_new(...)
    PREINIT:
        int r;
    CODE:
        dTHX;
        dSP;
        // TODO
        XSRETURN_YES;

void M_DESTROY(SV *m=NULL)
    PPCODE:
        dTHX;
        dSP;
        if(!THISSvOK(m))
            XSRETURN_YES;
        // TODO
        XSRETURN_YES;
