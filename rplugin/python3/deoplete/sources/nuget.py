from .base import Base
import netrc
import re
from urllib.parse import urlparse
import urllib.request as request
import json
import base64

class Source(Base):

    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'nuget'
        self.mark = '[nuget]'
        self.filetypes = ['xml', 'csproj']

    def gather_candidates(self, context):

        complete_str = context['complete_str']
        line = self.vim.call('getline', '.')
        col = self.vim.call('col', '.')-1
        to_cursor = line[:col]

        if '<PackageReference Include=\"' not in to_cursor:
            return []

        if 'Version="' in to_cursor:
            package = to_cursor.replace(' ', '')
            package = package.replace('<PackageReferenceInclude="', '')
            package = package.replace('"Version="%s' % complete_str, '')

            r = request.Request('https://api.nuget.org/v3-flatcontainer/%s/index.json' % package)

            with request.urlopen(r) as req:
                response_json = req.read().decode('utf-8')
                response = json.loads(response_json)

                titles = [{'word': x,
                           'menu': package + ' ' + x,
                           'info': package + ' ' + x}
                           for x in response.get('versions')]
                return titles
            return []

        r = request.Request('https://api-v2v3search-0.nuget.org/autocomplete?q=%s&take=100&includeDelisted=false' % complete_str)

        with request.urlopen(r) as req:
            response_json = req.read().decode('utf-8')
            response = json.loads(response_json)

            titles = [{'word': x,
                       'menu': x,
                       'info': x}
                       for x in response.get('data')]
            return titles
        return []
