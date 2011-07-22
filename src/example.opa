

import bddc.tablebuilder

/**
 *
 *
 *      DATAS
 *
 *
 *
*/

type vtest = {str : string i : int}
type vtest_k = {k : int v : vtest}
db /test : intmap(vtest)

init() =
    if not(Db.exists(@/test[0])) then
        do /test[0] <- {str="coucou" i=10}
        do /test[1] <- {str="salut" i=1}
        void

do init()

get_values() : list(vtest_k) =
    Db.intmap_fold_range(
        @/test,
        (acc,k -> List.add({~k v=/test[k]},acc)),
        [],0,none,(_->true)
    )
add(new_v : vtest) : int =
    key = Db.fresh_key(@/test)
    do save(key, new_v)
    key
save(key : int, new_v : vtest) = 
    /test[key] <- new_v
rm(key : int) =
    Db.remove(@/test[key])


/**
 *
 *
 *      TABLE
 *
 *
 *
*/



@client 
mk_columns() = [
            TableBuilder.mk_column(
                <>String</>,
                (r,_chan -> <>{r.v.str}</>),
                some(r1, r2 -> String.ordering(r1.v.str, r2.v.str)),
                none
            ),
            TableBuilder.mk_column(
                <>Int</>,
                (r,_chan -> <>{r.v.i}</>),
                some(r1, r2 -> Int.ordering(r1.v.i, r2.v.i)),
                none
            ),
            TableBuilder.mk_column(
                <>Tool</>,
                (r,chan -> 
                    <button onclick={_-> do Session.send(chan, {del_filter=(v->v.k == r.k)}) rm(r.k)}>Del filter</button>
                ),
                none,
                none
            )
        ]

onready() =
    values = get_values()
    spec = TableBuilder.mk_spec(
        mk_columns(),
        values
    )
    table = TableBuilder.make(spec)
    key() = String.to_int(Dom.get_value(#key))
    str() = Dom.get_value(#str)
    i() = String.to_int(Dom.get_value(#int))
    row_k() = {k=key() v={str=str() i=i()}}
    row() = {str=str() i=i()}
    // add
    onadd(_) = 
        k=add(row())
        row_k={~k v=row()}
        Session.send(table.channel, {add=row_k})
    // delete by key
    ondelkey(_) =
        do rm(key())
        Session.send(table.channel, {del_key=key()})
    // edit by key
    oneditkey(_) =
        do save(key(), row())
        Session.send(table.channel, {edit_key={key=key() row=row_k()}})
    xhtml = 
    <>
    str : <input id=#str/> 
    int : <input id=#int /> 
    key : <input id=#key/>
    <button onclick={onadd}>Ajouter</button>
    <button onclick={ondelkey}>Del key</button>
    <button onclick={oneditkey}>Editer key</button>
    {table.xhtml}
    </>
    Dom.transform([#onready <- xhtml])


/**
 *
 *
 *      SERVER
 *
 *
 *
*/


main() =
       <div id=#onready onready={_->onready()}></div>


server = Server.one_page_server("Test", main)
