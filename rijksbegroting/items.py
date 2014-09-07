# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# http://doc.scrapy.org/en/latest/topics/items.html

import scrapy


class BudgetItem(scrapy.Item):
    # define the fields for your item here like:
    bureau_code = scrapy.Field()
    bureau_name = scrapy.Field()
    uitgaven = scrapy.Field()
    ontvangsten = scrapy.Field()
    verplichtingen = scrapy.Field()

