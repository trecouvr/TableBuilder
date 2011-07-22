/*
 * (c) Valdabondance.com - 2011
 * @author Matthieu Guffroy - Thomas Recouvreux
 *
 */

package bddc.tools

Tools = {{

    list = {{
        replace(key : int, new_v : 'new_v, l : list('a)) : list('a) = 
            List.mapi((i,v -> if i==key then new_v else v), l)
    }}

    
    option = {{
        perform_default(f : ('o -> 'r), default : 'r, o : option('o)) : 'r =
            if Option.is_some(o) then
                f(Option.get(o))
            else
                default
    }}


}}
