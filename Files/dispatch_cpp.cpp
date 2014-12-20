#include "dispatch_cpp.h"

namespace __dispatch_cpp {
    
void __dispatch_cpp_exec_delete_lambda(void* context)
{
    auto l = reinterpret_cast<__lambda_exec*>(context);
    (*l)();
    delete l;
}
    
void __dispatch_cpp_appl_lambda(void* context, size_t it)
{
    auto l = reinterpret_cast<__lambda_apply*>(context);
    (*l)(it);
}

}
