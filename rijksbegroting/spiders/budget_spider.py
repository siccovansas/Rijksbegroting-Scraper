import scrapy
from scrapy.contrib.spiders import CrawlSpider, Rule
from scrapy.contrib.linkextractors import LinkExtractor
from rijksbegroting.items import BudgetItem

import re


class BudgetSpider(CrawlSpider):
    name = 'rijksbegroting'
    allowed_domains = ['rijksbegroting.nl']

    scrapy.log.start(logfile='log.txt', loglevel='DEBUG', logstdout=None)

    # 2013 URLs.
    start_urls = ['http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173844.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173846.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173847.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173888.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173850.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173852.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173856.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173858.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173860.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst174013.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173867.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173854.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173861.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173864.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173872.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst176579.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst176600.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173870.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173871.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173874.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173875.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173878.html',
		  'http://www.rijksbegroting.nl/2013/voorbereiding/begroting,kst173919.html',
		 ]

    def clean(self, txt):
	# Some cells are just empty, so return 0.
	if not txt:
	    return 0
	else:
	    txt = txt[0]

	# Some cells have 'nihil' as value, interpret this as 0.
	if txt == 'nihil':
	    return 0

	# Some cells have 'pm' as value, interpret this as 0.
	if txt == 'pm':
	    return 0

	# Remove whitespaces.
	txt = re.sub(ur'\xc2|\xa0|\s+', '', txt)
	# Change dash into minus
	txt = re.sub(ur'\u2013', '-', txt)

	if not re.match(r'-?\d+', txt):
	    return 0

	return int(txt)

    def parse(self, response):
        rows = response.xpath("//table/tbody/tr")
	for row in rows:
	    firstColumnItem = row.xpath("./td[@class = 'left'][1]/p[1]/text()").extract()
	    # If this column contains a number then we found a row with budget data!
	    if firstColumnItem and re.match(r'\d+', firstColumnItem[0]):
		budget = BudgetItem()
		budget['bureau_code'] = int(firstColumnItem[0])
		budget['bureau_name'] = row.xpath("./td[@class = 'left'][2]/p/text()").extract()[0]
		budget['verplichtingen'] = self.clean(row.xpath("./td[@class = 'right'][1]/p/text()").extract())
		budget['uitgaven'] = self.clean(row.xpath("./td[@class = 'right'][2]/p/text()").extract())
		budget['ontvangsten'] = self.clean(row.xpath("./td[@class = 'right'][3]/p/text()").extract())
		yield budget
