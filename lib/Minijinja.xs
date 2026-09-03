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
} cb_data_t;




static HV *cb_data_hv = NULL;

static void cb_data_init(pTHX) {
    if (!cb_data_hv) {
        cb_data_hv = newHV();
    }
}

static mj_value perl_to_mj_value(pTHX_ SV *sv);
static SV *mj_value_to_perl(pTHX_ mj_value val);

static mj_value perl_to_mj_value(pTHX_ SV *sv) {
    if (!sv || !SvOK(sv)) {
        return mj_value_new_undefined();
    }
    
    if (SvROK(sv)) {
        SV *rv = SvRV(sv);
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
        } else if (SvTYPE(rv) == SVt_PVHV) {
            HV *hv = (HV*)rv;
            mj_value obj = mj_value_new_object();
            HE *he;
            I32 key_len;
            const char *key;
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);
                mj_value mv = perl_to_mj_value(aTHX_ val);
                mj_value_set_string_key(&obj, key, mv);
            }
            return obj;
        }
    }
    
    if (SvIOK(sv) && !SvNOK(sv) && !SvPOK(sv)) {
        return mj_value_new_i64(SvIV(sv));
    }
    
    if (SvNOK(sv)) {
        return mj_value_new_f64(SvNV(sv));
    }
    
    if (SvPOK(sv)) {
        STRLEN len;
        const char *str = SvPV(sv, len);
        return mj_value_new_string(str);
    }
    
    return mj_value_new_undefined();
}

static SV *mj_value_to_perl(pTHX_ mj_value val) {
    mj_value_kind kind = mj_value_get_kind(val);
    
    switch (kind) {
        case MJ_VALUE_KIND_STRING: {
            char *str = mj_value_to_str(val);
            SV *sv = newSVpv(str, 0);
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
            return mj_value_is_true(val) ? &PL_sv_yes : &PL_sv_no;
        case MJ_VALUE_KIND_NONE:
        case MJ_VALUE_KIND_UNDEFINED:
            return &PL_sv_undef;
        case MJ_VALUE_KIND_SEQ: {
            AV *av = newAV();
            uint64_t len = mj_value_len(val);
            for (uint64_t i = 0; i < len; i++) {
                mj_value item = mj_value_get_by_index(val, i);
                SV *elem = mj_value_to_perl(aTHX_ item);
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
                    STRLEN key_len;
                    const char *key_str = SvPV(key_sv, key_len);
                    hv_store(hv, key_str, key_len, val_sv, 0);
                }
                mj_value_iter_free(iter);
            }
            return newRV_noinc((SV*)hv);
        }
        default:
            return &PL_sv_undef;
    }
}

/* Filter/function/test callback wrapper: C ABI args -> Perl scalars -> call_sub -> mj_value */
static bool cb_filter_wrapper(void *userdata,
                              const mj_value *args, uintptr_t argc,
                              mj_value *rv_out) {
    cb_data_t *cbd = (cb_data_t *)userdata; dTHX;
    IV n = 0; SV *svs[15]; for(uintptr_t i=0;i<argc&&i<15;i++){SV *a=mj_value_to_perl(aTHX_ args[i]);SvREFCNT_inc(a);svs[n++]=a;} I32 rc=0;dSP;ENTER;SAVETMPS;PUSHMARK(SP);for(IV j=0;j<n;j++)XPUSHs(svs[j]);PUTBACK;rc=perl_call_sv(cbd->code_ref,G_SCALAR);SPAGAIN; mj_value res;if(rc>0){SV *r=POPs;if(!SvOK(r)){res=mj_value_new_undefined();}else{res=perl_to_mj_value(aTHX_ r);}*rv_out=res;}else{res=mj_value_new_undefined();*rv_out=res;}FREETMPS;LEAVE;for(IV j=0;j<n;j++)SvREFCNT_dec(svs[j]);return true;}

/* Loader callback: template name -> user_sub -> string or NULL */
static const char *cb_loader_wrapper(void *userdata, const char *name) {
    cb_data_t *cbd=(cb_data_t*)userdata;dTHX; SV *arg=newSVpv(name,0);I32 rc=0;const char *result=NULL;dSP;ENTER;SAVETMPS;PUSHMARK(SP);XPUSHs(arg);PUTBACK;rc=perl_call_sv(cbd->code_ref,G_SCALAR|G_EVAL);SPAGAIN;if(rc>0){SV*r=POPs;if(!SvROK(r)||!(SvTYPE(SvRV(r))==SVt_PVMG&&mg_get(r))){if(SvOK(r)){STRLEN l;const char*s=SvPV(r,l);result=strdup(s);}}else result=NULL;}else result=NULL;FREETMPS;LEAVE;SvREFCNT_dec(arg);return result;}

/* Auto-escape callback: template name -> user_sub -> MJ_AUTO_ESCAPE_HTML or NONE */
static enum mj_auto_escape cb_auto_escape_wrapper(void *userdata, const char *name) {
    cb_data_t *cbd=(cb_data_t*)userdata;dTHX; SV *arg=newSVpv(name,0);I32 rc=0;int html=0;dSP;ENTER;SAVETMPS;PUSHMARK(SP);XPUSHs(arg);PUTBACK;rc=perl_call_sv(cbd->code_ref,G_SCALAR|G_EVAL);SPAGAIN;if(rc>0){SV*r=POPs;if(!SvROK(r)||!(SvTYPE(SvRV(r))==SVt_PVMG&&mg_get(r)))html=SvTRUE(r)?1:0;}FREETMPS;LEAVE;SvREFCNT_dec(arg);return html?MJ_AUTO_ESCAPE_HTML:MJ_AUTO_ESCAPE_NONE;}

/* Path join callback: (name,parent) -> user_sub -> joined path string or NULL */
static const char *cb_path_join_wrapper(void *userdata, const char *name, const char *parent) {
    cb_data_t *cbd=(cb_data_t*)userdata;dTHX; SV *a1=newSVpv(name,0),*a2=newSVpv(parent,0);I32 rc=0;const char *result=NULL;dSP;ENTER;SAVETMPS;PUSHMARK(SP);XPUSHs(a1);XPUSHs(a2);PUTBACK;rc=perl_call_sv(cbd->code_ref,G_SCALAR|G_EVAL);SPAGAIN;if(rc>0){SV*r=POPs;if(!SvROK(r)||!(SvTYPE(SvRV(r))==SVt_PVMG&&mg_get(r))){if(SvOK(r)){STRLEN l;const char*s=SvPV(r,l);result=strdup(s);}}else result=NULL;}else result=NULL;FREETMPS;LEAVE;SvREFCNT_dec(a1);SvREFCNT_dec(a2);return result;}
MODULE = Minijinja      PACKAGE = Minijinja     PREFIX = M_

VERSIONCHECK: DISABLE
PROTOTYPES: DISABLE

BOOT:
{
    cb_data_init(aTHX);
}

SV *M_new(...)
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

bool M_add_template(SV *env_sv, char *name, char *source)
    PREINIT:
        perl_mj_env_t *pe;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;
        RETVAL = mj_env_add_template(pe->env, name, source);
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

        if (items >= 3 && SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(ctx_sv);
            HE *he;
            I32 key_len;
            const char *key;

            ctx = mj_value_new_object();
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);
                mj_value mv = perl_to_mj_value(aTHX_ val);
                mj_value_set_string_key(&ctx, key, mv);
            }
        } else {
            ctx = mj_value_new_object();
        }

        char *result = mj_env_render_template(pe->env, name, ctx);
        if (result) {
            SV *sv = sv_newmortal();
            sv_setpv(sv, result);
            mj_str_free(result);
            ST(0) = sv;
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

SV *M_render_str(SV *env_sv, char *name, char *source, SV *ctx_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value ctx;
    CODE:
        dTHX;

        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;

        if (items >= 4 && SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(ctx_sv);
            HE *he;
            I32 key_len;
            const char *key;

            ctx = mj_value_new_object();
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);
                mj_value mv = perl_to_mj_value(aTHX_ val);
                mj_value_set_string_key(&ctx, key, mv);
            }
        } else {
            ctx = mj_value_new_object();
        }

        char *result = mj_env_render_named_str(pe->env, name, source, ctx);
        if (result) {
            SV *sv = sv_newmortal();
            sv_setpv(sv, result);
            mj_str_free(result);
            ST(0) = sv;
            XSRETURN(1);
        } else {
            XSRETURN_UNDEF;
        }

SV *M_eval_expr(SV *env_sv, char *expr, SV *ctx_sv)
    PREINIT:
        perl_mj_env_t *pe;
        mj_value ctx, result;
    CODE:
        dTHX;

        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv);
        if (pe->env == NULL) XSRETURN_UNDEF;

        if (items >= 3 && SvROK(ctx_sv) && SvTYPE(SvRV(ctx_sv)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(ctx_sv);
            HE *he;
            I32 key_len;
            const char *key;

            ctx = mj_value_new_object();
            hv_iterinit(hv);
            while ((he = hv_iternext(hv))) {
                key = hv_iterkey(he, &key_len);
                SV *val = hv_iterval(hv, he);
                mj_value mv = perl_to_mj_value(aTHX_ val);
                mj_value_set_string_key(&ctx, key, mv);
            }
        } else {
            ctx = mj_value_new_object();
        }

        result = mj_env_eval_expr(pe->env, expr, ctx);
        ST(0) = mj_value_to_perl(aTHX_ result);
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
        Newxz(cbd, 1, cb_data_t); cbd->pe = pe; cbd->code_ref = code_ref; SvREFCNT_inc(code_ref);
        char kbuf[256]; int idx=0; STRLEN kl; do{snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"filter");}while(hv_exists(cb_data_hv,kbuf,strlen(kbuf))); hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_add_filter(pe->env, name, cb_filter_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_add_function(SV *env_sv, char *name, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe; cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv); if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) { croak("add_function requires a code reference"); }
        Newxz(cbd, 1, cb_data_t); cbd->pe = pe; cbd->code_ref = code_ref; SvREFCNT_inc(code_ref);
        char kbuf[256]; int idx=0; STRLEN kl; do{snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"function");}while(hv_exists(cb_data_hv,kbuf,strlen(kbuf))); hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_add_function(pe->env, name, cb_filter_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_add_test(SV *env_sv, char *name, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe; cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv); if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) { croak("add_test requires a code reference"); }
        Newxz(cbd, 1, cb_data_t); cbd->pe = pe; cbd->code_ref = code_ref; SvREFCNT_inc(code_ref);
        char kbuf[256]; int idx=0; STRLEN kl; do{snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"test");}while(hv_exists(cb_data_hv,kbuf,strlen(kbuf))); hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_add_test(pe->env, name, cb_filter_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_set_loader(SV *env_sv, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe; cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv); if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) { croak("set_loader requires a code reference"); }
        Newxz(cbd, 1, cb_data_t); cbd->pe = pe; cbd->code_ref = code_ref; SvREFCNT_inc(code_ref);
        char kbuf[256]; int idx=0; STRLEN kl; do{snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"loader");}while(hv_exists(cb_data_hv,kbuf,strlen(kbuf))); hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_set_loader(pe->env, cb_loader_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_set_auto_escape(SV *env_sv, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe; cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv); if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) { croak("set_auto_escape requires a code reference"); }
        Newxz(cbd, 1, cb_data_t); cbd->pe = pe; cbd->code_ref = code_ref; SvREFCNT_inc(code_ref);
        char kbuf[256]; int idx=0; STRLEN kl; do{snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"autoescape");}while(hv_exists(cb_data_hv,kbuf,strlen(kbuf))); hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
        RETVAL = mj_env_set_auto_escape_callback(pe->env, cb_auto_escape_wrapper, cbd, NULL);
    OUTPUT: RETVAL

bool M_set_path_join(SV *env_sv, SV *code_ref)
    PREINIT:
        perl_mj_env_t *pe; cb_data_t *cbd;
    CODE:
        dTHX;
        if (!THISSvOK(env_sv)) XSRETURN_UNDEF;
        pe = THIS(env_sv); if (pe->env == NULL) XSRETURN_UNDEF;
        if (!SvROK(code_ref) || SvTYPE(SvRV(code_ref)) != SVt_PVCV) { croak("set_path_join requires a code reference"); }
        Newxz(cbd, 1, cb_data_t); cbd->pe = pe; cbd->code_ref = code_ref; SvREFCNT_inc(code_ref);
        char kbuf[256]; int idx=0; STRLEN kl; do{snprintf(kbuf,sizeof(kbuf),"%p:%d:%s",(void*)pe->env,idx++,"pathjoin");}while(hv_exists(cb_data_hv,kbuf,strlen(kbuf))); hv_store(cb_data_hv,kbuf,strlen(kbuf),newSViv(PTR2IV(cbd)),0);
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
        char *detail = mj_err_get_detail();
        if (detail) {
            ST(0) = sv_2mortal(newSVpv(detail, 0));
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
            XSRETURN(-1);
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
