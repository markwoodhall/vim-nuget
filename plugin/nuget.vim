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
  \ 'sink': function('s:PackageVersionsNoSink')})
endfunction

function! s:CompletePackage(A, L, P) abort
  let result = webapi#http#get('https://api-v2v3search-0.nuget.org/autocomplete?q='.a:A.'&take=100&includeDelisted=false')
  return eval(result.content).data
endfunction

function! s:PackageVersionsNoSink(package) abort
    call s:PackageVersions(a:package, 's:PackageInfo')
endfunction

function! s:PackageVersions(package, sink) abort
  let result = webapi#http#get('https://api.nuget.org/v3-flatcontainer/'.a:package.'/index.json')
  let s:actions = reverse(eval(substitute(result.content, '\r\n', '', 'g')).versions)
  let s:package = a:package
  call fzf#run({
  \ 'source': s:actions,
  \ 'down': '40%',
  \ 'sink': function(a:sink)})
  if s:action == 'search'
    call feedkeys("a")
    let s:action = ''
  endif
endfunction

function! s:PackageCache()
  let s:actions = split(system('find ~/.nuget/packages/ -name *.dll'), '\n')
  call fzf#run({
  \ 'source': s:actions,
  \ 'down': '40%',
  \ 'sink': function('s:LoadAssembly')})
endfunction

function! s:LoadAssembly(assembly)
    let lines = ['LoadAssembly("'.a:assembly.'");']
    call append(1, lines)
endfunction

function! s:PackageInfoUnderCursor()
    let line = getline('.')
    let length = len(line)
    let col = col('.')-1
    let to_cursor = line[col:length]
    let package = split(to_cursor, '-')[0]
    let pversion = split(to_cursor, '-')[1]
    let s:package = package
    call s:PackageInfo(pversion)
endfunction

function! s:PackageInfo(version) abort
  let s:version = a:version
  let result = webapi#http#get('https://api.nuget.org/v3/registration0/'.tolower(s:package).'/'.a:version.'.json')
  let catalogEntry = eval(substitute(substitute(result.content, 'true', '1', 'g'), 'false', '0', 'g')).catalogEntry

  let result = webapi#http#get(catalogEntry)
  let result = eval(substitute(substitute(substitute(result.content, '\r\n', '', 'g'), 'true', '1', 'g'), 'false', '0', 'g'))
  let targetFrameworks = []
  if has_key(result, 'dependencyGroups')
    for d in result.dependencyGroups
        let targetFrameworks = targetFrameworks + [d.targetFramework]
        if has_key(d, 'dependencies')
            for de in d.dependencies
                let targetFrameworks = targetFrameworks + ['   > '. de.id.'-'. split(split(de.range, '[')[0], ',')[0]]
            endfor
        endif
    endfor
  endif
  let status =  result.isPrerelease ? ' - Beta' : ''
  let lines = ['#'.s:package.' - '.a:version. '' . status, '', result.description, '', '*Last Published at:'.result.published.'*', '', '##Target Frameworks:', '']
  for tf in targetFrameworks
      let lines = lines + [tf]
  endfor
  let lines = lines + ['', '##Url', '', has_key(result, 'projectUrl') ? result.projectUrl : 'Not available']
  let lines = lines + ['', '##Authors', '', has_key(result, 'authors') ? result.authors : 'Not available']
  let lines = lines + ['', '##License', '', has_key(result, 'licenseUrl') ? result.licenseUrl : 'Not available']
  let lines = lines + ['', '##Tags', '']
  if has_key(result, 'tags')
    for t in result.tags
        let lines = lines + ['   > '.t]
    endfor
  endif
  let command = expand('%b') =~ '__Nuget_Package' ? 'e' : 'split'
  execute command '__Nuget_Package-'.s:package.'-'.a:version
    setlocal filetype=markdown
    setlocal buftype=nofile
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :PackageInfoUnderCursor<CR>
  nnoremap <silent> <buffer> I :InstallThisPackage<CR>
endfunction

autocmd filetype markdown command! -buffer PackageInfoUnderCursor :exe s:PackageInfoUnderCursor()
autocmd filetype markdown command! -buffer InstallThisPackage :exe s:InstallPackage(s:version)

autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -complete=customlist,s:CompletePackage -buffer InstallPackage :exe s:PackageVersions(<q-args>, 's:InstallPackage')
autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -complete=customlist,s:CompletePackage -buffer RemovePackage :exe s:RemovePackage(<q-args>)
autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -buffer SearchPackages :exe s:PackageSearch(<q-args>)
autocmd BufNewFile,BufRead *.cs,*.csproj command! -buffer PackageCache :exe s:PackageCache()
autocmd BufNewFile,BufRead *.cs,*.csproj command! -nargs=1 -complete=customlist,s:CompletePackage -buffer PackageInfo :exe s:PackageVersions(<q-args>, 's:PackageInfo')

autocmd filetype cs command! -nargs=1 -complete=customlist,s:CompletePackage -buffer InstallPackage :exe s:PackageVersions(<q-args>, 's:InstallPackage')
autocmd filetype cs command! -nargs=1 -complete=customlist,s:CompletePackage -buffer RemovePackage :exe s:RemovePackage(<q-args>)
autocmd filetype cs command! -nargs=1 -buffer SearchPackages :exe s:PackageSearch(<q-args>)
autocmd filetype cs command! -buffer PackageCache :exe s:PackageCache()
autocmd filetype cs command! -nargs=1 -complete=customlist,s:CompletePackage -buffer PackageInfo :exe s:PackageVersions(<q-args>, 's:PackageInfo')
