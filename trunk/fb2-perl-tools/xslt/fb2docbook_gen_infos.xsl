<?xml version="1.0" encoding="UTF-8"?>
<!-- 
    
    Copyright 2007 by KiR Jakobson ( http://kir666.ru/fb2docbook/ )
    
    This library is free software; you can redistribute it and/or modify
    it under the terms of the General Public License (GPL).  For
    more information, see http://www.fsf.org/licenses/gpl.txt
    
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0"
    xmlns:exsl="http://exslt.org/common" xmlns:date="http://exslt.org/dates-and-times"
    xmlns:redirect="http://xml.apache.org/xalan/redirect"
    extension-element-prefixes="exsl date redirect" version="1.1">
    <xsl:import href="l10n/gentext.xsl"/>
    <xsl:template name="technical-appendix">
        <appendix id="{concat('tappendix', generate-id())}">
            <title id="{concat('tappendix_title', generate-id())}">
                <xsl:call-template name="gentext.info.title">
                    <xsl:with-param name="context" select="'technical-appendix'"/>
                </xsl:call-template>
            </title>
            <para>
                <xsl:call-template name="gentext.info.param">
                    <xsl:with-param name="context" select="'technical-appendix'"/>
                    <xsl:with-param name="param" select="'xslt.processor'"/>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
                <ulink url="{system-property('xsl:vendor-url')}">
                    <xsl:value-of select="system-property('xsl:vendor')"/>
                </ulink> (XSLT version <xsl:value-of select="system-property('xsl:version')"/>). </para>
            <xsl:if test="function-available('date:date-time')">
                <para>
                    <xsl:call-template name="gentext.info.param">
                        <xsl:with-param name="context" select="'technical-appendix'"/>
                        <xsl:with-param name="param" select="'conversion-date-time'"/>
                    </xsl:call-template>
                    <xsl:text>: </xsl:text>
                    <xsl:value-of select="date:date-time()"/>                    
                </para>
            </xsl:if>
        </appendix>
    </xsl:template>
    <xsl:template name="title-info-appendix">
        <xsl:if test="count(fb:description/fb:title-info) and count(fb:description/fb:title-info/*)">
            <xsl:for-each select="fb:description/fb:title-info">
                <xsl:call-template name="title-info-appendix-wrk">
                    <xsl:with-param name="my_id"
                        select="concat('title-info-appendix', generate-id())"/>
                    <xsl:with-param name="my_title">
                        <xsl:call-template name="gentext.info.title"/>
                    </xsl:with-param>
                    <xsl:with-param name="my_annotation_id" select="'preface_annotation'"/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template name="src-title-info-appendix">
        <xsl:if
            test="count(fb:description/fb:src-title-info) and count(fb:description/fb:src-title-info/*)">
            <xsl:for-each select="fb:description/fb:src-title-info">
                <xsl:call-template name="title-info-appendix-wrk">
                    <xsl:with-param name="my_id"
                        select="concat('src-title-info-appendix', generate-id())"/>
                    <xsl:with-param name="my_title">
                        <xsl:call-template name="gentext.info.title"/>
                    </xsl:with-param>
                    <xsl:with-param name="my_annotation_id" select="'preface_annotation_original'"/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template name="entry-tbl-title">
        <entry align="left">
            <simpara>
                <emphasis role="strong">
                    <xsl:call-template name="gentext.info.param"/>
                </emphasis>
            </simpara>
        </entry>
    </xsl:template>
    <xsl:template name="title-info-appendix-wrk">
        <xsl:param name="my_id"/>
        <xsl:param name="my_title"/>
        <xsl:param name="my_annotation_id"/>
        <appendix id="{$my_id}">
            <title>
                <xsl:value-of select="$my_title"/>
            </title>
            <informaltable align="center" frame="topbot" colsep="0" rowsep="1">
                <tgroup cols="2">
                    <colspec colnum="1" colname="col1" colwidth="1*"/>
                    <colspec colnum="2" colname="col2" colwidth="2*"/>
                    <tbody>
                        <xsl:if test="count(fb:genre)">
                            <row>
                                <xsl:for-each select="fb:genre[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-genres"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:author)">
                            <row>
                                <xsl:for-each select="fb:author[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-authors"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:book-title)">
                            <row>
                                <xsl:for-each select="fb:book-title[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:book-title/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:annotation)">
                            <row>
                                <xsl:for-each select="fb:annotation[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-annotation">
                                        <xsl:with-param name="my_annotation_id"
                                            select="$my_annotation_id"/>
                                    </xsl:call-template>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:keywords)">
                            <row>
                                <xsl:for-each select="fb:keywords[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-keywords"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:date)">
                            <row>
                                <xsl:for-each select="fb:date[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-date"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:coverpage)">
                            <row>
                                <xsl:for-each select="fb:coverpage[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-coverpage">
                                        <xsl:with-param name="my_annotation_id"
                                            select="$my_annotation_id"/>
                                    </xsl:call-template>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:lang)">
                            <row>
                                <xsl:for-each select="fb:lang[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-lang"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:src-lang)">
                            <row>
                                <xsl:for-each select="fb:src-lang[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-src-lang"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:translator)">
                            <row>
                                <xsl:for-each select="fb:translator[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-translators"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:sequence)">
                            <row>
                                <xsl:for-each select="fb:sequence[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-sequence"/>
                                </entry>
                            </row>
                        </xsl:if>
                    </tbody>
                </tgroup>
            </informaltable>
        </appendix>
    </xsl:template>
    <xsl:template name="title-info-genres">
        <xsl:choose>
            <xsl:when test="count(fb:genre) &gt; 1">
                <itemizedlist spacing="compact">
                    <xsl:for-each select="fb:genre">
                        <listitem>
                            <simpara>
                                <xsl:value-of select="text()"/>
                                <xsl:if test="@match != ''"> (<xsl:value-of select="@match"
                                />%)</xsl:if>
                            </simpara>
                        </listitem>
                    </xsl:for-each>
                </itemizedlist>
            </xsl:when>
            <xsl:otherwise>
                <simpara>
                    <xsl:for-each select="fb:genre">
                        <xsl:value-of select="text()"/>
                        <xsl:if test="@match != ''"> (<xsl:value-of select="@match"/>%)</xsl:if>
                    </xsl:for-each>
                </simpara>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="title-info-authors">
        <xsl:choose>
            <xsl:when test="count(fb:author) &gt; 1">
                <itemizedlist spacing="compact">
                    <xsl:for-each select="fb:author">
                        <listitem>
                            <simpara>
                                <xsl:apply-templates mode="bookinfo"/>
                            </simpara>
                        </listitem>
                    </xsl:for-each>
                </itemizedlist>
            </xsl:when>
            <xsl:otherwise>
                <simpara>
                    <xsl:for-each select="fb:author">
                        <xsl:apply-templates mode="bookinfo"/>
                    </xsl:for-each>
                </simpara>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>
    <xsl:template name="title-info-annotation">
        <xsl:param name="my_annotation_id"/>
        <simpara>
            <xsl:call-template name="gentext.param">
                <xsl:with-param name="param" select="'SeeAbr'"/>
            </xsl:call-template>
            <xsl:text> </xsl:text>
            <xref linkend="{$my_annotation_id}"/>
        </simpara>
    </xsl:template>
    <xsl:template name="title-info-keywords">
        <simpara>
            <xsl:value-of select="fb:keywords/text()"/>
        </simpara>
    </xsl:template>
    <xsl:template name="title-info-date">
        <simpara>
            <xsl:value-of select="fb:date/text()"/>
            <xsl:if test="fb:date/@value"> (<xsl:value-of select="fb:date/@value"/>)</xsl:if>
        </simpara>
    </xsl:template>
    <xsl:template name="title-info-coverpage">
        <xsl:param name="my_annotation_id"/>
        <simpara>
            <xsl:call-template name="gentext.param">
                <xsl:with-param name="param" select="'SeeAbr'"/>
            </xsl:call-template>
            <xsl:text> </xsl:text>
            <xref linkend="{$my_annotation_id}"/>
        </simpara>
    </xsl:template>
    <xsl:template name="title-info-lang">
        <simpara>
            <xsl:value-of select="fb:lang/text()"/>
        </simpara>
    </xsl:template>
    <xsl:template name="title-info-src-lang">
        <simpara>
            <xsl:value-of select="fb:src-lang/text()"/>
        </simpara>
    </xsl:template>
    <xsl:template name="title-info-translators">
        <xsl:choose>
            <xsl:when test="count(fb:translator) &gt; 1">
                <itemizedlist spacing="compact">
                    <xsl:for-each select="fb:translator">
                        <listitem>
                            <simpara>
                                <xsl:apply-templates mode="bookinfo"/>
                            </simpara>
                        </listitem>
                    </xsl:for-each>
                </itemizedlist>
            </xsl:when>
            <xsl:otherwise>
                <simpara>
                    <xsl:for-each select="fb:translator">
                        <xsl:apply-templates mode="bookinfo"/>
                    </xsl:for-each>
                </simpara>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="title-info-sequence">
        <simpara>
            <xsl:value-of select="fb:sequence/@name"/>
        </simpara>
        <simpara>
            <xsl:if test="fb:sequence/@number">
                <xsl:call-template name="gentext.info.param">
                    <xsl:with-param name="context" select="'title-info'"/>
                    <xsl:with-param name="param" select="'sequence.number'"/>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
                <xsl:value-of select="fb:sequence/@number"/>
            </xsl:if>
        </simpara>
    </xsl:template>
    <xsl:template name="document-info-appendix">
        <xsl:if
            test="count(fb:description/fb:document-info) and count(fb:description/fb:document-info/*)">
            <xsl:for-each select="fb:description/fb:document-info">
                <xsl:call-template name="document-info-appendix-wrk"/>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template name="document-info-appendix-wrk">
        <appendix id="{concat('document-info-appendix', generate-id())}">
            <title>
                <xsl:call-template name="gentext.info.title"/>
            </title>
            <informaltable align="center" frame="topbot" colsep="0" rowsep="1">
                <tgroup cols="2">
                    <colspec colnum="1" colname="col1" colwidth="1*"/>
                    <colspec colnum="2" colname="col2" colwidth="2*"/>
                    <tbody>
                        <xsl:if test="count(fb:author)">
                            <row>
                                <xsl:for-each select="fb:author[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-authors"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:program-used)">
                            <row>
                                <xsl:for-each select="fb:program-used[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:program-used/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:date)">
                            <row>
                                <xsl:for-each select="fb:date[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="title-info-date"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:src-url)">
                            <row>
                                <xsl:for-each select="fb:src-url[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="document-info-src-url"/>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:src-ocr)">
                            <row>
                                <xsl:for-each select="fb:src-ocr[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:src-ocr/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:id)">
                            <row>
                                <xsl:for-each select="fb:id[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <code>
                                            <?db-font-size 50% ?>
                                            <xsl:value-of select="fb:id/text()"/>
                                        </code>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:version)">
                            <row>
                                <xsl:for-each select="fb:version[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:version/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:history)">
                            <row>
                                <!-- TODO to bookinfo, xref + publisher element-->
                                <xsl:for-each select="fb:history[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <xsl:call-template name="document-info-history"/>
                                </entry>
                            </row>
                        </xsl:if>
                    </tbody>
                </tgroup>
            </informaltable>
        </appendix>
    </xsl:template>
    <xsl:template name="document-info-src-url">
        <simpara>
            <ulink url="{fb:src-url/text()}">
                <xsl:value-of select="fb:src-url/text()"/>
            </ulink>
        </simpara>
    </xsl:template>
    <xsl:template name="document-info-history">
        <xsl:apply-templates select="fb:history/*"/>
    </xsl:template>
    <xsl:template name="publish-info-appendix">
        <xsl:if
            test="count(fb:description/fb:publish-info) and count(fb:description/fb:publish-info/*)">
            <xsl:for-each select="fb:description/fb:publish-info">
                <xsl:call-template name="publish-info-appendix-wrk"/>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template name="publish-info-appendix-wrk">
        <appendix id="{concat('publish-info-appendix', generate-id())}">
            <title>
                <xsl:call-template name="gentext.info.title"/>
            </title>
            <informaltable align="center" frame="topbot" colsep="0" rowsep="1">
                <tgroup cols="2">
                    <colspec colnum="1" colname="col1" colwidth="1*"/>
                    <colspec colnum="2" colname="col2" colwidth="2*"/>
                    <tbody>
                        <xsl:if test="count(fb:book-name)">
                            <row>
                                <xsl:for-each select="fb:book-name[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:book-name/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:publisher)">
                            <row>
                                <xsl:for-each select="fb:publisher[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:publisher/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:city)">
                            <row>
                                <xsl:for-each select="fb:city[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:city/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:year)">
                            <row>
                                <xsl:for-each select="fb:year[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:year/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <xsl:if test="count(fb:isbn)">
                            <row>
                                <xsl:for-each select="fb:isbn[1]">
                                    <xsl:call-template name="entry-tbl-title"/>
                                </xsl:for-each>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="fb:isbn/text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:if>
                        <!-- + sequence element -->
                    </tbody>
                </tgroup>
            </informaltable>
        </appendix>
    </xsl:template>
    <xsl:template name="custom-info-appendix">
        <xsl:if
            test="count(fb:description/fb:custom-info) and count(fb:description/fb:custom-info/*)">
            <appendix id="{concat('custom-info-appendix', generate-id())}">
                <xsl:for-each select="fb:description/fb:custom-info[1]">
                    <title>
                        <xsl:call-template name="gentext.info.title"/>
                    </title>
                </xsl:for-each>
                <xsl:for-each select="fb:description/fb:custom-info">
                    <formalpara>
                        <title>
                            <xsl:value-of select="@info-type"/>
                        </title>
                        <para>
                            <code>
                                <xsl:value-of select="text()"/>
                            </code>
                        </para>
                    </formalpara>
                </xsl:for-each>
                <!--informaltable align="center" frame="topbot" colsep="0" rowsep="1">
                <tgroup cols="2">
                    <colspec colnum="1" colname="col1" colwidth="1*"/>
                    <colspec colnum="2" colname="col2" colwidth="2*"/>
                    <thead>
                        <row>
                            <entry>Тип</entry>
                            <entry>Информация</entry>
                        </row>
                    </thead>

                    <tbody>
                        <xsl:for-each select="fb:description/fb:custom-info">
                            <row>
                                <entry align="left">
                                    <simpara>
                                        <emphasis role="strong">
                                            <xsl:value-of select="@info-type"/>
                                        </emphasis>
                                    </simpara>
                                </entry>
                                <entry align="left">
                                    <simpara>
                                        <xsl:value-of select="text()"/>
                                    </simpara>
                                </entry>
                            </row>
                        </xsl:for-each>
                    </tbody>
                </tgroup>
                </informaltable-->
            </appendix>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
