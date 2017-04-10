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
        self.input_pattern = '\w*'

    def gather_candidates(self, context):

        r = request.Request('https://api-v2v3search-0.nuget.org/autocomplete?q=%s' % context['complete_str'])

        with request.urlopen(r) as req:
            response_json = req.read().decode('utf-8')
            response = json.loads(response_json)

            titles = [{'word': x,
                       'menu': x,
                       'info': x}
                       for x in response.get('data')]
            return titles
        return []
