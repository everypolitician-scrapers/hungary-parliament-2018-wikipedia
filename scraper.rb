#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator RemoveNotes
  decorator WikidataIdsDecorator::Links

  field :members do
    (constituency_members + national_members).reject { |mem| mem[:name].to_s.empty? }.each do |mem|
      mem[:party_id] = parties.find(->() {{}}) { |party| party[:name] == mem[:party] }[:id]
    end
  end

  field :parties do
    @parties ||= noko.css('#Frakcióvezetők').xpath('following::ul[1]/li').map { |li| fragment(li => Party).to_h }
  end

  private

  def constituency_members
    constituency_member_table.xpath('.//tr[td]').map { |tr| fragment(tr => ConstituencyMemberRow) }.map(&:to_h)
  end

  def national_members
    national_member_table.xpath('.//tr[td]').map { |tr| fragment(tr => NationalMemberRow) }.map(&:to_h)
  end

  def constituency_member_table
    noko.xpath('//h3[contains(.,"Egyéni választókerületben")]/following::table[1]')
  end

  def national_member_table
    noko.xpath('//h3[contains(.,"Országos listáról")]/following::table[1]')
  end

end

class Party < Scraped::HTML
  field :id do
    links.first.attr('wikidata')
  end

  field :name do
    links.first.text
  end

  private

  def links
    noko.css('a')
  end
end

class NationalMemberRow < Scraped::HTML
  field :id do
    tds[0].css('a/@wikidata').map(&:text).first
  end

  field :name do
    tds[0].css('a').map(&:text).first
  end

  field :party do
    tds[1].text.tidy
  end

  private

  def tds
    noko.css('td')
  end
end

class ConstituencyMemberRow < NationalMemberRow
  field :constituency do
    tds[2].text.tidy
  end

  field :constituency_wikidata do
    tds[2].css('a/@wikidata').map(&:text).first
  end
end

url = URI.encode 'https://hu.wikipedia.org/wiki/2018–2022_közötti_magyar_országgyűlési_képviselők_listája'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name party])
