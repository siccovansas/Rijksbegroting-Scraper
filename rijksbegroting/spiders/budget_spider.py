import scrapy
from scrapy import log
from scrapy.http import Request
from scrapy.contrib.spiders import CrawlSpider, Rule
from scrapy.contrib.linkextractors import LinkExtractor
from rijksbegroting.items import BudgetItem

import re


class BudgetSpider(CrawlSpider):
    name = 'rijksbegroting'
    allowed_domains = ['rijksbegroting.nl']
    
    scrapy.log.start(logfile='log.txt', loglevel='ERROR', logstdout=None)

    # The links to the 2012, 2013 and 2014 budgets can be retrieved from this page.
    start_urls = ['http://www.rijksbegroting.nl/2014/voorbereiding/begroting']
    # Process the overview page of each year to retrieve the department pages.
    rules = [Rule(LinkExtractor(allow=['/\d{4}/voorbereiding/begroting$']), 'get_budget_links')]

    # Cleans up the budget data which do not simply exist out of integers but can contain
    # text, e.g. 'nihil' or 'pm', and are full of spaces and dots, etc.
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

        # Remove dots (used as thousands separator in some budgets).
        txt =re.sub(ur'\.', '', txt)
	# Remove whitespaces.
	txt = re.sub(ur'\xc2|\xa0|\s+', '', txt)
	# Change dash into minus
	txt = re.sub(ur'\u2013', '-', txt)

	if not re.match(r'-?\d+', txt):
	    return 0

	return int(txt)

    # Retrieve all 20+ department pages from the budget overview page of the selected year.
    def get_budget_links(self, response):
        links = response.xpath("//ol/li/a[starts-with(@id, 'hoofdstuk')]/@href").extract()
        data = []
        for link in links:
            yield Request(url='http://www.rijksbegroting.nl' + link, callback=self.get_budget_law)

    # On each department page we need to follow the link to the law page which holds the budget data.
    def get_budget_law(self, response):
        link = response.xpath('//a[@class = "arrow-orange"]/@href').extract()[0]
        yield Request(url='http://www.rijksbegroting.nl' + link, callback=self.parse_budget)

    # Finally we reach the page with budget data for the current department and year.
    def parse_budget(self, response):
        # The year and department code and name are the same for each budget on this year.
        year = response.xpath("//ol[@class='breadcrumb']/li[2]/a/@title").extract()[0]
        department_info = response.xpath("//ol[@class='breadcrumb']/li[5]/a/@title").extract()[0]
        match_obj = re.match(r'([^\s]+) (.*)', department_info)
        department_code = match_obj.group(1)
        department_name = match_obj.group(2)

        # Read out each row which contains budget data for a specific bureau.
        rows = response.xpath("//table/tbody/tr")
	for row in rows:
	    firstColumnItem = row.xpath("./td[1]/p[1]/text()").extract()
	    # If this column contains a number then we found a row with budget data!
	    if firstColumnItem and re.match(r'\d+', firstColumnItem[0]):
		budget = BudgetItem()
                budget['year'] = year
                budget['department_code'] = department_code
                budget['department_name'] = department_name
                # Lovely exception for http://www.rijksbegroting.nl/2012/voorbereiding/begroting,kst160368.html.
                # They forgot to split the 'Art.' and 'Omschrijving' into two columns as with every other table,
                # and instead combined them :S.
                match_obj = re.match(r'(\d+)\s+(\w+.*)', firstColumnItem[0])
                if match_obj:
                    budget['bureau_code'] = int(match_obj.group(1))
	    	    budget['bureau_name'] = re.sub(ur'\s+', ' ', match_obj.group(2)).strip()
                    budget['verplichtingen'] = self.clean(row.xpath("./td[2]/p/text()").extract())
                    budget['uitgaven'] = self.clean(row.xpath("./td[3]/p/text()").extract())
                    budget['ontvangsten'] = self.clean(row.xpath("./td[4]/p/text()").extract())
                    #bureau_data = firstColumnItem[0].split(' ')
                    #budget['bureau_code'] = int(bureau_data[0])
                    #budget['bureau_name'] = re.sub(ur'\s+', ' ', bureau_data[1])
                else:
        	    budget['bureau_code'] = int(firstColumnItem[0])
	    	    bureau_name = row.xpath("./td[2]/p/text()").extract()[0]
	    	    budget['bureau_name'] = re.sub(ur'\s+', ' ', bureau_name).strip()
                    budget['verplichtingen'] = self.clean(row.xpath("./td[3]/p/text()").extract())
                    budget['uitgaven'] = self.clean(row.xpath("./td[4]/p/text()").extract())
                    budget['ontvangsten'] = self.clean(row.xpath("./td[5]/p/text()").extract())
                yield budget
