if exists('g:loaded_nuget') || &cp
  finish
endif

let g:loaded_nuget = 1

if !exists('g:nuget_install_with_neomake')
  let g:nuget_install_with_neomake = 0
endif
let s:action = ''

function! s:FindProject()
  let filename = expand('%:t:r')
  let filepath = expand('%:p:h')
  let project_files = split(glob(filepath . '/*.csproj'), '\n')
  let search_for_csproj = 1
 
  while len(project_files) == 0 && search_for_csproj
    let filepath_parts = split(filepath, '/') 
    let search_for_csproj = len(filepath_parts) > 1
    let filepath = '/'.join(filepath_parts[0:-2], '/')
    let project_files = split(glob(filepath . '/*.csproj'), '\n')
  endwhile
  if len(project_files) == 0
    throw 'Unable to find .csproj file, a .csproj file is required to make use of the `dotnet test` command.'
  endif
  return project_files[0]
endfunction

function! s:InstallPackage(version)
  let project = s:FindProject()
  if g:nuget_install_with_neomake 
    let maker = {'exe': 'dotnet', 'name': 'dotnet', 'args': ['add', project, 'package', s:package, '-v', a:version]}
    call neomake#Make(0, [maker])
    return
  endif
  execute '!dotnet add ' project . ' package ' . s:package . ' -v ' a:version
endfunction

function! s:RemovePackage(package)
  let project = s:FindProject()
  if g:nuget_install_with_neomake 
    let maker = {'exe': 'dotnet', 'name': 'dotnet', 'args': ['remove', project, 'package', a:package]}
    call neomake#Make(0, [maker])
    return
  endif
  execute '!dotnet remove ' project . ' package ' . a:package
endfunction

function! s:PackageSearch(query) abort
  let result = webapi#http#get('https://api-v2v3search-0.nuget.org/query?q='.a:query.'&take=100&includeDelisted=false')
  let s:action = 'search'
  let s:actions = []
  for package in eval(result.content).data
    let s:actions = s:actions + [package.id]
  endfor
  call fzf#run({
  \ 'source': s:actions,
  \ 'down': '40%',
  \ 'sink': function('s:PackageVersions')})
endfunction

function! s:CompletePackage(A, L, P) abort
  let result = webapi#http#get('https://api-v2v3search-0.nuget.org/autocomplete?q='.a:A.'&take=100&includeDelisted=false')
  return eval(result.content).data
endfunction

function! s:PackageVersions(package) abort
  let result = webapi#http#get('https://api.nuget.org/v3-flatcontainer/'.a:package.'/index.json')
  let s:actions = reverse(eval(substitute(result.content, '\r\n', '', 'g')).versions)
  let s:package = a:package
  call fzf#run({
  \ 'source': s:actions,
  \ 'down': '40%',
  \ 'sink': function('s:InstallPackage')})
  if s:action == 'search'
    call feedkeys("a")
    let s:action = ''
  endif
endfunction

autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -complete=customlist,s:CompletePackage -buffer InstallPackage :exe s:PackageVersions(<q-args>)
autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -complete=customlist,s:CompletePackage -buffer RemovePackage :exe s:RemovePackage(<q-args>)
autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -buffer SearchPackages :exe s:PackageSearch(<q-args>)
