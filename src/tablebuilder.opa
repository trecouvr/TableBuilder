/*
 * 
 * @author Thomas Recouvreux
 *
 */

package bddc.tablebuilder
import stdlib.core.rpc.core
import bddc.tools



@abstract type TableBuilder.message('row) = 
    {show} /
    {sort : int} /
    {del_key : int} / 
    {del_filter : ('row->bool)} / 
    {edit_key : {key:int row:'row}} /
    {edit_filter : ('row->'row)} /
    {add : 'row}
type TableBuilder.row_order('row) = ('row,'row -> Order.ordering)
type TableBuilder.row_filter('row) = ('row -> bool)
@abstract type TableBuilder.column('row) = {
    label : xhtml
    cell_maker : ('row,channel(TableBuilder.message('row)) -> xhtml)
    order : option(TableBuilder.row_order('row))
    sort_reverse : bool
    filter : option(TableBuilder.row_filter('row))
    filter_on : bool
}
@abstract type TableBuilder.spec('row) = {
    id : string
    columns : list(TableBuilder.column('row))
    content : list('row)
    sort_active : int
}
type TableBuilder.t('row) = {
    xhtml : xhtml
    channel : channel(TableBuilder.message('row))
}





TableBuilder = {{
    mk_spec( columns : list(TableBuilder.column),
             content : list('row)
           ) : TableBuilder.spec('row) =
        {
            id = Dom.fresh_id()
            ~columns
            ~content
            sort_active=0
        }
    mk_column( label : xhtml,
               cell_maker : ('row,channel(TableBuilder.message('row)) -> xhtml),
               order : option(TableBuilder.row_order('row)),
               filter : option(TableBuilder.row_filter('row))
             ) : TableBuilder.column =
        {
            ~label
            ~cell_maker
            ~order
            ~filter
            sort_reverse=true
            filter_on=false
        }
    
    /**
    Cré une session qui va contenir la spec du tableau, renvoi un record contenant
    le channel pour communiquer et agir sur le tableau et le code xhtml necessaire
    à l'affichage du tableau
    @param spec
    @return (TableBuilder.t)
    */
    @client
    make(spec : TableBuilder.spec('row)) : TableBuilder.t =
        rec val channel = Session.make(spec, callback)
        and callback(spec,message) =
            do jlog("{message}")
            new_spec = match message with
                       | {show} -> spec
                       | {~sort} -> onclick_sort(sort, spec)
                       | {~del_key} -> {spec with content=List.remove_at(del_key,spec.content)}
                       | {~del_filter} -> {spec with content=List.filter(v->not(del_filter(v)),spec.content)}
                       | {~edit_key} -> {spec with content=Tools.list.replace(edit_key.key, edit_key.row, spec.content)}
                       | {~edit_filter} -> {spec with content=List.map(edit_filter, spec.content)}
                       | {~add} -> {spec with content=List.add(add,spec.content)}
                       end
            new_spec = sort(new_spec)
            do Dom.transform([#{spec.id} <- xhtml_table(new_spec, channel)])
            {set=new_spec}
        {~channel xhtml=xhtml(spec,channel)}
    

    set_sort(i_col : int, spec : TableBuilder.spec('row)) : TableBuilder.spec('row) =
        {spec with sort_active=i_col}
    
    set_reverse(i_col : int, value : bool, spec : TableBuilder.spec('row)) : TableBuilder.spec('row) =
        col = List.get(i_col,spec.columns)
        if Option.is_some(col) then
            col = Option.get(col)
            col = {col with sort_reverse=value}
            {spec with columns = Tools.list.replace(i_col, col, spec.columns)}
        else spec
    
    /**
    Fonction appellée quand on clique pour trier le tableau, 
    elle va modifier la spec pour préciser la colonne de trie choisie
    et inverser l'ordre de tri de cette colonne
    @param i_col la colonne à utiliser pour le tri
    @param spec
    @return spec
    */
    @client
    @private
    onclick_sort(i_col : int, spec : TableBuilder.spec('row)) : TableBuilder.spec('row) = 
        Tools.option.perform_default(
            (col -> set_sort(i_col, set_reverse(i_col, not(col.sort_reverse), spec))),
            ->spec,
            List.get(i_col,spec.columns)
        )
    
    /**
    Trier la spec, la colonne à utiliséer pour le tri est précisée
    dans la spec
    @param spec
    @return spec
    */
    @client
    @private
    sort(spec : TableBuilder.spec('row)) : TableBuilder.spec('row) = 
        Tools.option.perform_default(
            (col -> Tools.option.perform_default(
                (ord ->
                    if col.sort_reverse then
                        {spec with content = List.rev(List.sort_with(ord,spec.content))}
                    else
                        {spec with content = List.sort_with(ord,spec.content)}
                ),
                ->spec,
                col.order
            )),
            ->spec,
            List.get(spec.sort_active,spec.columns)
        )
    
    /**
    Cré le tableau (seulement les balises exterieures)
    @param spec
    @param channel
    @return (xhtml)
    */
    @client
    @private
    xhtml(spec : TableBuilder.spec('row), channel : channel(TableBuilder.message('row))) : xhtml = 
        <table border=1 id=#{spec.id} onready={_->Session.send(channel,{show})}>
        </table>
    
    /**
    Cré la contenu du tableau
    @param spec
    @param channel
    @return (xhtml)
    */
    @client
    @private
    xhtml_table(spec : TableBuilder.spec('row), channel : channel(TableBuilder.message('row))) : xhtml =
        xhtml_header(s : TableBuilder.spec('row)) : xhtml =
            List.foldi( (i,col,acc -> 
                            <>{acc}<th>{col.label}<>{
                            if Option.is_some(col.order) then
                                <button onclick={_-> Session.send(channel,{sort=i})}>⇅</button>
                            else
                                <></>
                            }</></th></>
                        ),
                        spec.columns,
                        <></>)
        xhtml_body(s : TableBuilder.spec('row)) : xhtml =
            List.fold( (row,acc ->
                           <>{acc}
                           <tr>
                           {List.fold( (col,acc ->
                                           <>{acc}
                                           <td>{col.cell_maker(row, channel)}</td>
                                           </>
                                       ),
                                       s.columns,
                                       <></>
                           )}
                           </tr>
                           </>
                       ),
                       spec.content,
                       <></>)
        <thead>
        {xhtml_header(spec)}
        </thead>
        <tbody>
        {xhtml_body(spec)}
        </tbody>
    
    
    @client
    rm_key(chan : channel(TableBuilder.message('row)), key : int) : void =
        do Session.send(chan, {del_key=key})
        void

    @client
    rm_filter(chan : channel(TableBuilder.message('row)), filter : ('row->bool)) : void =
        do Session.send(chan, {del_filter=filter})
        void

    @client
    edit_key(chan : channel(TableBuilder.message('row)), key : int, row : 'row) : void =
        do Session.send(chan, {edit_key={~key ~row}})
        void

    @client
    edit_filter(chan : channel(TableBuilder.message('row)), filter : ('row -> 'row)) : void =
        do Session.send(chan, {edit_filter=filter})
        void

    @client
    add(chan : channel(TableBuilder.message('row)), row : 'row) : void =
        do Session.send(chan, {add=row})
        void
    
    
}}

