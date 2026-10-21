#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define PERLIO_NOT_STDIO 0
#include <perlio.h>

#include <minijinja.h>

#define THIS(sv)   INT2PTR(perl_mj_env_t *, SvIV(SvRV(sv)))
#define THISSvOK(sv) (sv != NULL && SvROK(sv) && SvOK(SvRV(sv)) && THIS(sv) != NULL)

typedef struct perl_mj_env {
    mj_env *env;
} perl_mj_env_t;

typedef struct cb_data {
    perl_mj_env_t *pe;
    SV *code_ref;
    SV *result;  /* a loader / path join result: minijinja copies it before the next call */
} cb_data_t;

/* Thread-local storage for exception handling */
static int mj_exception_set = 0;
static char *mj_pending_exception = NULL;

static void mj_clear_exception(pTHX) {
    mj_exception_set = 0;
    Safefree(mj_pending_exception);
    mj_pending_exception = NULL;
}

/* A string SV's text as UTF-8 for minijinja, without changing the SV: a string without the UTF8 flag holds
 * Latin-1 characters, so a mortal copy is upgraded when it has bytes >= 0x80 */
static const char *sv_utf8_cstr(pTHX_ SV *sv) {
    STRLEN l, i;
    const char *s = SvPV(sv, l);
    if (SvUTF8(sv)) return s;
    for (i = 0; i < l && !((U8)s[i] & 0x80); i++) ;
    if (i == l) return s;
    return SvPVutf8_nolen(sv_2mortal(newSVpvn(s, l)));
}

/* A UTF-8 string from minijinja as a Perl character string */
static SV *utf8_sv(pTHX_ const char *s) {
    return newSVpvn_flags(s, strlen(s), SVf_UTF8);
}

/* Keeps a copy of the message of a callback that died, for error_detail */
static void mj_set_exception(pTHX_ SV *err) {
    mj_clear_exception(aTHX);
    mj_pending_exception = savepv(sv_utf8_cstr(aTHX_ err));
    mj_exception_set = 1;
}

static int mj_has_pending_exception(pTHX) {
    return mj_exception_set && mj_pending_exception != NULL;
}

static const char *mj_get_pending_exception(pTHX) {
    if (mj_has_pending_exception(aTHX)) {
        return mj_pending_exception;
    }
    return NULL;
}



static HV *cb_data_hv = NULL;

static void cb_data_init(pTHX) {
    if (!cb_data_hv) {
        cb_data_hv = newHV();
    }
}

static mj_value perl_to_mj_value(pTHX_ SV *sv);
static SV *mj_value_to_perl(pTHX_ mj_value val);

static mj_value perl_to_mj_value(pTHX_ SV *sv) {
    if (sv) SvGETMAGIC(sv);
    if (!sv || !SvOK(sv)) {
        return mj_value_new_undefined();
    }

    /* Check for blessed scalar refs first (e.g., JSON::PP Boolean). These may or may not
     * have an RV component depending on how they were created. */
    if (SvROK(sv)) {
        SV *rv = SvRV(sv);

        /* Array reference — convert to minijinja list */
        if (SvTYPE(rv) == SVt_PVAV) {
            AV *av = (AV*)rv;
            mj_value list = mj_value_new_list();
            I32 len = av_top_index(av) + 1;
            for (I32 i = 0; i < len; i++) {
                SV **elem = av_fetch(av, i, 0);
                if (elem) {
                    mj_value item = perl_to_mj_value(aTHX_ *elem);
                    mj_value_append(&list, item);
                }
            }
            return list;
        }

        /* Hash reference — convert to minijinja object */
        if (SvTYPE(rv) == SVt_PVHV) {
            HV *hv = (HV*)rv;
            mj_value obj = mj_value_new_object();
            HE *he;
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                SV *val = hv_iterval(hv, he);
                mj_value mv = perl_to_mj_value(aTHX_ val);
                mj_value_set_string_key(&obj, sv_utf8_cstr(aTHX_ hv_iterkeysv(he)), mv);
            }
            return obj;
        }

        /* Scalar reference that is not array/hash — check for JSON::PP Boolean or stringify */
        if (!SvOK(rv)) {
            return mj_value_new_undefined();
        }
        /* Check for blessed scalar (e.g., JSON::PP Boolean). Minijinja treats any value whose string
         * representation is empty or "0" as a boolean false. We replicate this behavior here. */
        if (SvOBJECT(rv)) {
            STRLEN len;
            const char *str = SvPV_nolen(rv);
            int is_false = (strcmp(str, "0") == 0 || str[0] == '\0');
            return mj_value_new_bool(is_false ? 0 : 1);
        }
        /* Non-blessed scalar ref: treat as string */
        const char *str = sv_utf8_cstr(aTHX_ rv);
        if (str[0] == '\0') {
            return mj_value_new_bool(0);
        }
        return mj_value_new_string(str);
    }

    if (SvIOK(sv) && !SvNOK(sv) && !SvPOK(sv)) {
        return mj_value_new_i64(SvIV(sv));
    }

    if (SvNOK(sv)) {
        return mj_value_new_f64(SvNV(sv));
    }

    if (SvPOK(sv)) {
        return mj_value_new_string(sv_utf8_cstr(aTHX_ sv));
    }

    return mj_value_new_undefined();
}

static SV *mj_value_to_perl(pTHX_ mj_value val) {
    mj_value_kind kind = mj_value_get_kind(val);

    switch (kind) {
        case MJ_VALUE_KIND_STRING: {
            char *str = mj_value_to_str(val);
            SV *sv = utf8_sv(aTHX_ str);
            mj_str_free(str);
            return sv;
        }
        case MJ_VALUE_KIND_NUMBER: {
            double f = mj_value_as_f64(val);
            if (f == (int64_t)f) {
                return newSViv((IV)f);
            } else {
                return newSVnv(f);
            }
        }
        case MJ_VALUE_KIND_BOOL:
            return newSVsv(mj_value_is_true(val) ? &PL_sv_yes : &PL_sv_no);
        case MJ_VALUE_KIND_NONE:
        case MJ_VALUE_KIND_UNDEFINED:
            return newSV(0);
        case MJ_VALUE_KIND_SEQ: {
            AV *av = newAV();
            uint64_t len = mj_value_len(val);
            for (uint64_t i = 0; i < len; i++) {
                mj_value item = mj_value_get_by_index(val, i);  /* a new reference */
                SV *elem = mj_value_to_perl(aTHX_ item);
                mj_value_decref(&item);
                av_push(av, elem);
            }
            return newRV_noinc((SV*)av);
        }
        case MJ_VALUE_KIND_MAP: {
            HV *hv = newHV();
            mj_value_iter *iter = mj_value_try_iter(val);
            if (iter) {
                mj_value key, value;
                while (mj_value_iter_next(iter, &key)) {
                    value = mj_value_get_by_value(val, key);
                    SV *key_sv = mj_value_to_perl(aTHX_ key);
                    SV *val_sv = mj_value_to_perl(aTHX_ value);
                    hv_store_ent(hv, key_sv, val_sv, 0);
                    SvREFCNT_dec(key_sv);
                    mj_value_decref(&value);  /* key and value are new references */
                    mj_value_decref(&key);
                }
                mj_value_iter_free(iter);
            }
            return newRV_noinc((SV*)hv);
        }
        default:
            return newSV(0);
    }
}

/* Filter/function/test callback wrapper: C ABI args -> Perl scalars -> call_sub -> mj_value */
static bool cb_filter_wrapper(void *userdata,
                              const mj_value *args, uintptr_t argc,
                              mj_value *rv_out) {
    cb_data_t *cbd = (cb_data_t *)userdata; dTHX;

    I32 rc=0;
    bool ok;
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    for(uintptr_t i=0;i<argc;i++)
        XPUSHs(sv_2mortal(mj_value_to_perl(aTHX_ args[i])));
    PUTBACK;

    /* Call the sub with G_EVAL so die/croak are caught in $@. In scalar context a sub that died still
     * returns one value (undef), so success is an empty $@, not the count. */
    rc=perl_call_sv(cbd->code_ref,G_SCALAR|G_EVAL);
    SPAGAIN;
    SV *r = rc > 0 ? POPs : &PL_sv_undef;
    PUTBACK;

    ok = !SvTRUE(ERRSV);
    if(ok){
        *rv_out = perl_to_mj_value(aTHX_ r);
    } else {
        /* Keep the message for error_detail; returning false makes minijinja abort the rendering */
        mj_set_exception(aTHX_ ERRSV);
        *rv_out = mj_value_new_undefined();
    }
    FREETMPS;
    LEAVE;
    return ok;
}


/* A loader / path join callback's string result as UTF-8, or NULL for undef or a die */
static const char *cb_string_result(pTHX_ cb_data_t *cbd, I32 rc, SV *r) {
    if (rc <= 0 || SvTRUE(ERRSV)) return NULL;
    SvGETMAGIC(r);
    if (!SvOK(r)) return NULL;
    if (!cbd->result) cbd->result = newSV(0);
    sv_setpv(cbd->result, sv_utf8_cstr(aTHX_ r));
    return SvPVX(cbd->result);
}

/* Loader callback: template name -> user_sub -> string or NULL */
static const char *cb_loader_wrapper(void *userdata, const char *name) {
    cb_data_t *cbd = (cb_data_t*)userdata; dTHX;
    I32 rc = 0;
    const char *result = NULL;
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(utf8_sv(aTHX_ name)));
    PUTBACK;
    rc = perl_call_sv(cbd->code_ref, G_SCALAR|G_EVAL);
    SPAGAIN;
    SV *r = rc > 0 ? POPs : &PL_sv_undef;
    PUTBACK;
    result = cb_string_result(aTHX_ cbd, rc, r);
    FREETMPS;
    LEAVE;
    return result;
}

/* Auto-escape callback: template name -> user_sub -> MJ_AUTO_ESCAPE_HTML or NONE */
static enum mj_auto_escape cb_auto_escape_wrapper(void *userdata, const char *name) {
    cb_data_t *cbd = (cb_data_t*)userdata; dTHX;
    I32 rc = 0;
    int html = 0;
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(utf8_sv(aTHX_ name)));
    PUTBACK;
    rc = perl_call_sv(cbd->code_ref, G_SCALAR|G_EVAL);
    SPAGAIN;
    SV *r = rc > 0 ? POPs : &PL_sv_undef;
    PUTBACK;
    if (rc > 0 && !SvTRUE(ERRSV))
        html = SvTRUE(r) ? 1 : 0;
    FREETMPS;
    LEAVE;
    return html ? MJ_AUTO_ESCAPE_HTML : MJ_AUTO_ESCAPE_NONE;
}

/* Path join callback: (name,parent) -> user_sub -> joined path string or NULL */
static const char *cb_path_join_wrapper(void *userdata, const char *name, const char *parent) {
    cb_data_t *cbd = (cb_data_t*)userdata; dTHX;
    I32 rc = 0;
    const char *result = NULL;
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(utf8_sv(aTHX_ name)));
    XPUSHs(sv_2mortal(utf8_sv(aTHX_ parent)));
    PUTBACK;
    rc = perl_call_sv(cbd->code_ref, G_SCALAR|G_EVAL);
    SPAGAIN;
    SV *r = rc > 0 ? POPs : &PL_sv_undef;
    PUTBACK;
    result = cb_string_result(aTHX_ cbd, rc, r);
    FREETMPS;
    LEAVE;
    return result;
}

MODULE = Minijinja      PACKAGE = Minijinja     PREFIX = M_

VERSIONCHECK: DISABLE
PROTOTYPES: DISABLE

BOOT:
{
    cb_data_init(aTHX);
}

SV *M_create_minijinja(...)
    CODE:
        dTHX; dSP;

        perl_mj_env_t *pe = NULL;
        Newxz(pe, 1, perl_mj_env_t);
        if (!pe) croak("out of memory");

        pe->env = mj_env_new();
        if (!pe->env) {
            Safefree(pe);
            XSRETURN_UNDEF;
        }

        HV *hv = NULL;
        if (items > 1 && SvROK(ST(1)) && SvTYPE(SvRV(ST(1))) == SVt_PVHV) {
            hv = (HV*)SvRV(ST(1));
            HE *he;
            const char *key;
            I32 key_len;
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);
                if (strEQ(key, "debug")) {
                    mj_env_set_debug(pe->env, SvTRUE(val));
                } else if (strEQ(key, "fuel")) {
                    mj_env_set_fuel(pe->env, (uint64_t)SvUV(val));
                } else if (strEQ(key, "recursion_limit")) {
                    mj_env_set_recursion_limit(pe->env, (uint32_t)SvUV(val));
                } else if (strEQ(key, "trim_blocks")) {
                    mj_env_set_trim_blocks(pe->env, SvTRUE(val));
                } else if (strEQ(key, "lstrip_blocks")) {
                    mj_env_set_lstrip_blocks(pe->env, SvTRUE(val));
                } else if (strEQ(key, "keep_trailing_newline")) {
                    mj_env_set_keep_trailing_newline(pe->env, SvTRUE(val));
                } else if (strEQ(key, "undefined_behavior")) {
                    mj_env_set_undefined_behavior(pe->env, (mj_undefined_behavior)SvIV(val));
                }
            }
        }

        SV *sv = sv_newmortal();
        SvPOK_only(sv);
        sv_setref_pv(sv, "Minijinja", pe);
        ST(0) = sv;
        XSRETURN(1);

void M_DESTROY(SV *sv)
    CODE:
        dTHX;
        if (!THISSvOK(sv)) return;

        perl_mj_env_t *pe = THIS(sv);
        if (pe->env != NULL) {
            mj_env_free(pe->env);
            pe->env = NULL;
        }
        Safefree(pe);

bool M_add_template(SV *env_sv, char *name, SV *source)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        RETVAL = mj_env_add_template(pe->env, name, sv_utf8_cstr(aTHX_ source));
    OUTPUT:
        RETVAL

bool M_remove_template(SV *env_sv, char *name)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        RETVAL = mj_env_remove_template(pe->env, name);
    OUTPUT:
        RETVAL

bool M_clear_templates(SV *env_sv)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        RETVAL = mj_env_clear_templates(pe->env);
    OUTPUT:
        RETVAL

SV *M_render_template(SV *env_sv, char *name, SV *ctx_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value ctx;
    CODE:
        dTHX;

        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;

        mj_clear_exception(aTHX);
        ctx = items >= 3 && SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV
            ? perl_to_mj_value(aTHX_ ctx_sv) : mj_value_new_object();

        char *result = mj_env_render_template(pe->env, name, ctx);
        if (result) {
            SV *sv = sv_2mortal(utf8_sv(aTHX_ result));
            mj_str_free(result);
            ST(0) = sv;
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

SV *M_render_str(SV *env_sv, char *name, SV *source, SV *ctx_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value ctx;
    CODE:
        dTHX;

        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;

        mj_clear_exception(aTHX);
        ctx = items >= 4 && SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV
            ? perl_to_mj_value(aTHX_ ctx_sv) : mj_value_new_object();

        char *result = mj_env_render_named_str(pe->env, name, sv_utf8_cstr(aTHX_ source), ctx);
        if (result) {
            SV *sv = sv_2mortal(utf8_sv(aTHX_ result));
            mj_str_free(result);
            ST(0) = sv;
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

SV *M_eval_expr(SV *env_sv, SV *expr, SV *ctx_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value ctx, result;
    CODE:
        dTHX;

        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;

        mj_clear_exception(aTHX);
        ctx = items >= 3 && SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV
            ? perl_to_mj_value(aTHX_ ctx_sv) : mj_value_new_object();

        result = mj_env_eval_expr(pe->env, sv_utf8_cstr(aTHX_ expr), ctx);
        ST(0) = sv_2mortal(mj_value_to_perl(aTHX_ result));
        mj_value_decref(&result);
        XSRETURN(1);

bool M_add_global(SV *env_sv, char *name, SV *val_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value val;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        val = perl_to_mj_value(aTHX_ val_sv);
        RETVAL = mj_env_add_global(pe->env, name, val);
    OUTPUT:
        RETVAL

void M_set_debug(SV *env_sv, bool val)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_debug(pe->env, val);

void M_set_fuel(SV *env_sv, SV *val)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_fuel(pe->env, (uint64_t)SvUV(val));

void M_clear_fuel(SV *env_sv)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_clear_fuel(pe->env);

void M_set_recursion_limit(SV *env_sv, SV *val)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_recursion_limit(pe->env, (uint32_t)SvUV(val));

void M_set_trim_blocks(SV *env_sv, bool val)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_trim_blocks(pe->env, val);

void M_set_lstrip_blocks(SV *env_sv, bool val)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_lstrip_blocks(pe->env, val);

void M_set_keep_trailing_newline(SV *env_sv, bool val)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_keep_trailing_newline(pe->env, val);

void M_set_undefined_behavior(SV *env_sv, int mode)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) return;
        pe = THIS(env_sv);
        if (pe->env == NULL) return;
        mj_env_set_undefined_behavior(pe->env, (mj_undefined_behavior)mode);

void M_apply_syntax(SV *env_sv, SV *opts_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_syntax_config config;
        int has_opts = 0;
    CODE:
        dTHX;

        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;

        has_opts = (items >= 2);

        mj_syntax_config_default(&config);

        if (has_opts && SvROK(opts_sv) && SvTYPE(SvRV(opts_sv)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(opts_sv);
            HE *he;
            I32 key_len;
            const char *key;

            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);
                STRLEN val_len;
                const char *str_val = SvPV(val, val_len);

                if (strEQ(key, "block_start")) config.block_start = str_val;
                else if (strEQ(key, "block_end")) config.block_end = str_val;
                else if (strEQ(key, "variable_start")) config.variable_start = str_val;
                else if (strEQ(key, "variable_end")) config.variable_end = str_val;
                else if (strEQ(key, "comment_start")) config.comment_start = str_val;
                else if (strEQ(key, "comment_end")) config.comment_end = str_val;
                else if (strEQ(key, "line_statement_prefix")) config.line_statement_prefix = str_val;
                else if (strEQ(key, "line_comment_prefix")) config.line_comment_prefix = str_val;
            }
        }

        bool success = mj_env_set_syntax_config(pe->env, &config);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), success ? 1 : 0);
        XSRETURN(1);

bool M_add_filter(SV *env_sv, char *name, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe;
        cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) {
            croak("add_filter requires a code reference");
        }
        Newxz(cbd, 1, cb_data_t);
        cbd->pe = pe;
        cbd->code_ref = code_ref;
        SvREFCNT_inc(code_ref);
        char kbuf[256];
        int idx = 0;
        STRLEN kl;
        do{
            snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"filter");
        }while(hv_exists(cb_data_hv,kbuf,strlen(kbuf)));
        hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_add_filter(pe->env, name, cb_filter_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_add_function(SV *env_sv, char *name, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe;
        cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) {
            croak("add_function requires a code reference");
        }
        Newxz(cbd, 1, cb_data_t);
        cbd->pe = pe;
        cbd->code_ref = code_ref;
        SvREFCNT_inc(code_ref);
        char kbuf[256];
        int idx = 0;
        STRLEN kl;
        do{
            snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"function");
        }while(hv_exists(cb_data_hv,kbuf,strlen(kbuf)));
        hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_add_function(pe->env, name, cb_filter_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_add_test(SV *env_sv, char *name, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe;
        cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) {
            croak("add_test requires a code reference");
        }
        Newxz(cbd, 1, cb_data_t);
        cbd->pe = pe;
        cbd->code_ref = code_ref;
        SvREFCNT_inc(code_ref);
        char kbuf[256];
        int idx = 0;
        STRLEN kl;
        do{
            snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"test");
        }while(hv_exists(cb_data_hv,kbuf,strlen(kbuf)));
        hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_add_test(pe->env, name, cb_filter_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_set_loader(SV *env_sv, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe;
        cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) {
            croak("set_loader requires a code reference");
        }
        Newxz(cbd, 1, cb_data_t);
        cbd->pe = pe;
        cbd->code_ref = code_ref;
        SvREFCNT_inc(code_ref);
        char kbuf[256];
        int idx = 0;
        STRLEN kl;
        do{
            snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"loader");
        }while(hv_exists(cb_data_hv,kbuf,strlen(kbuf)));
        hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_set_loader(pe->env, cb_loader_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_set_auto_escape(SV *env_sv, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe;
        cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) {
            croak("set_auto_escape requires a code reference");
        }
        Newxz(cbd, 1, cb_data_t);
        cbd->pe = pe;
        cbd->code_ref = code_ref;
        SvREFCNT_inc(code_ref);
        char kbuf[256];
        int idx = 0;
        STRLEN kl;
        do{
            snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"autoescape");
        }while(hv_exists(cb_data_hv,kbuf,strlen(kbuf)));
        hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_set_auto_escape_callback(pe->env, cb_auto_escape_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_set_path_join(SV *env_sv, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe;
        cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) {
            croak("set_path_join requires a code reference");
        }
        Newxz(cbd, 1, cb_data_t);
        cbd->pe = pe;
        cbd->code_ref = code_ref;
        SvREFCNT_inc(code_ref);
        char kbuf[256];
        int idx = 0;
        STRLEN kl;
        do{
            snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"pathjoin");
        }while(hv_exists(cb_data_hv,kbuf,strlen(kbuf)));
        hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_set_path_join_callback(pe->env, cb_path_join_wrapper, cbd, NULL);
    OUTPUT: RETVAL

SV *M_error_exists()
    CODE:
        dTHX;
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), mj_err_is_set() ? 1 : 0);
        XSRETURN(1);

char *M_error_detail()
    CODE:
        dTHX;
        /* Check for pending exception from user callback die/croak */
        if (mj_has_pending_exception(aTHX) && mj_get_pending_exception(aTHX)) {
            ST(0) = sv_2mortal(utf8_sv(aTHX_ mj_get_pending_exception(aTHX)));
            mj_clear_exception(aTHX);
            XSRETURN(1);
        }
        char *detail = mj_err_get_detail();
        if (detail) {
            ST(0) = sv_2mortal(utf8_sv(aTHX_ detail));
            mj_str_free(detail);
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

char *M_error_debug_info()
    CODE:
        dTHX;
        char *info = mj_err_get_debug_info();
        if (info) {
            ST(0) = sv_2mortal(newSVpv(info, 0));
            mj_str_free(info);
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

int M_error_kind()
    CODE:
        dTHX;
        if (!mj_err_is_set()) {
            XSRETURN_UNDEF;
        } else {
            ST(0) = sv_2mortal(newSViv((IV)mj_err_get_kind()));
            XSRETURN(1);
        }

int M_error_line()
    CODE:
        dTHX;
        if (!mj_err_is_set()) {
            XSRETURN(0);
        } else {
            ST(0) = sv_2mortal(newSViv((IV)mj_err_get_line()));
            XSRETURN(1);
        }

char *M_error_template_name()
    CODE:
        dTHX;
        char *name = mj_err_get_template_name();
        if (name) {
            ST(0) = sv_2mortal(newSVpv(name, 0));
            mj_str_free(name);
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

SV *M_error_print()
    CODE:
        dTHX;
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), mj_err_print() ? 1 : 0);
        XSRETURN(1);
