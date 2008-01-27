<!-- Copyright (c) 2004 Dmitry Gribov (GribUser)
                   2008 Nikolay Shaplov
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote products
    derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0">
	<xsl:output method="html" encoding="utf-8"/>
	<xsl:param name="PageN">1</xsl:param>
	<xsl:param name="TotalPages">1</xsl:param>
	<xsl:param name="BookTitle">NoName</xsl:param>
	<xsl:param name="FileName">noname</xsl:param>
	<xsl:template match="/*">
		<html>
			<head>
				<title>
					<xsl:value-of select="$BookTitle"/>
				</title>
				<style type="text/css" media="screen">
					A { color : #0002CC }
					A:HOVER { color : #BF0000 }
					BODY { background-color : #FEFEFE; color : #000000; font-family : Verdana, Geneva, Arial, Helvetica, sans-serif; text-align : justify }
					H1{ font-size : 160%; font-style : normal; font-weight : bold; text-align : left; text-transform : capitalize;  border : 1px solid Black;  background-color : #E7E7E7; text-transform : capitalize;  margin-left : 0px;  padding-left : 0.5em;  }
					H2{ font-size : 130%; font-style : normal; font-weight : bold; text-align : left; text-transform : capitalize;  background-color : #EEEEEE;  border : 1px solid Gray; text-transform : capitalize;  padding-left : 1em; }
					H3{ font-size : 110%; font-style : normal; font-weight : bold; text-align : left;  background-color : #F1F1F1;  border : 1px solid Silver; text-transform : capitalize;  padding-left : 1.5em;}
					H4{ font-size : 100%; font-style : normal; font-weight : bold; text-align : left   padding-left : 0.5em; text-transform : capitalize;  border : 1px solid Gray;  background-color : #F4F4F4;  padding-left : 2em;}
					H5{ font-size : 100%; font-style : italic; font-weight : bold; text-align : left; text-transform : capitalize;border : 1px solid Gray;  background-color : #F4F4F4;  padding-left : 2.5em;}
					H6{ font-size : 100%; font-style : italic; font-weight : normal; text-align : left; text-transform : capitalize;border : 1px solid Gray;  background-color : #F4F4F4;  padding-left : 2.5em;}
					SMALL{ font-size : 80% }
					BLOCKQUOTE{ margin : 0 1em 0.2em 4em }
					HR{ color : Black }
					UL{ padding-left : 1em; margin-left: 0}
					.epigraph{width:50%; margin-left : 35%;}
				</style>
				<style type="text/css" media="print">
					A { color : #0002CC }
					A:HOVER { color : #BF0000 }
					BODY { background-color : #FEFEFE; color : #000000; font-family : "Times New Roman", Times, serif; text-align : justify }
					H1{ font-family : Verdana, Geneva, Arial, Helvetica, sans-serif; font-size : 160%; font-style : normal; font-weight : bold; text-align : left; text-transform : capitalize }
					H2{ font-family : Verdana, Geneva, Arial, Helvetica, sans-serif; font-size : 130%; font-style : normal; font-weight : bold; text-align : left; text-transform : capitalize }
					H3{ font-family : Verdana, Geneva, Arial, Helvetica, sans-serif; font-size : 110%; font-style : normal; font-weight : bold; text-align : left }
					H4{ font-family : Verdana, Geneva, Arial, Helvetica, sans-serif; font-size : 100%; font-style : normal; font-weight : bold; text-align : left }
					H5,H6{ font-family : Verdana, Geneva, Arial, Helvetica, sans-serif; font-size : 100%; font-style : italic; font-weight : normal; text-align : left; text-transform : uppercase }
					SMALL{ font-size : 80% }
					BLOCKQUOTE{ margin : 0 1em 0.2em 4em }
					HR{ color : Black }
				</style>
			</head>
			<body>
				<div><xsl:call-template name="for"/></div>
				<br/>
				<xsl:apply-templates/>
				<br/>
				<div><xsl:call-template name="for"/></div>
			</body>
		</html>
	</xsl:template>
	<xsl:template match="toc-item">
		<div>
			<xsl:attribute name="style">padding-left: <xsl:value-of select="@deep"/>em;</xsl:attribute>
			<a href="{$FileName}_{@n}.html"><xsl:apply-templates/></a>
		</div>
	</xsl:template>
	<xsl:template match="description">
		<xsl:apply-templates select="title-info/coverpage/image"/>
		<h1><xsl:apply-templates select="title-info/book-title"/></h1>
			<h2>
			<small>
				<xsl:for-each select="title-info/author">
						<b>
							<xsl:call-template name="author"/>
						</b>
				</xsl:for-each>
			</small>
		</h2>
		<xsl:if test="title-info/sequence">
			<p>
				<xsl:for-each select="title-info/sequence">
					<xsl:call-template name="sequence"/><br/>
				</xsl:for-each>
			</p>
		</xsl:if>
		<xsl:for-each select="title-info/annotation">
			<div>
				<xsl:call-template name="annotation"/>
			</div>
			<hr/>
		</xsl:for-each>
	</xsl:template>
	<!-- author template -->
	<xsl:template name="author">
		<xsl:value-of select="first-name"/>
		<xsl:text disable-output-escaping="no">&#032;</xsl:text>
		<xsl:value-of select="middle-name"/>&#032;
         <xsl:text disable-output-escaping="no">&#032;</xsl:text>
		<xsl:value-of select="last-name"/>
		<br/>
	</xsl:template>
	<!-- secuence template -->
	<xsl:template name="sequence">
		<LI/>
		<xsl:value-of select="@name"/>
		<xsl:if test="@number">
			<xsl:text disable-output-escaping="no">,&#032;#</xsl:text>
			<xsl:value-of select="@number"/>
		</xsl:if>
		<xsl:if test="sequence">
			<UL>
				<xsl:for-each select="sequence">
					<xsl:call-template name="sequence"/>
				</xsl:for-each>
			</UL>
		</xsl:if>
		<!--      <br/> -->
	</xsl:template>
	<xsl:template match="fb:subtitle">
		<xsl:if test="@id">
			<xsl:element name="a">
				<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
			</xsl:element>
		</xsl:if>
		<h5>
			<xsl:apply-templates/>
		</h5>
	</xsl:template>

	<xsl:template match="p">
		<div align="justify"><xsl:if test="@id">
				<xsl:element name="a">
					<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
				</xsl:element>
			</xsl:if>	&#160;&#160;&#160;<xsl:apply-templates/></div>
	</xsl:template>
	<!-- strong -->
	<xsl:template match="strong">
		<b><xsl:apply-templates/></b>
	</xsl:template>
	<!-- emphasis -->
	<xsl:template match="emphasis">
		<i>	<xsl:apply-templates/></i>
	</xsl:template>
	<!-- style -->
	<xsl:template match="style">
		<span class="{@name}"><xsl:apply-templates/></span>
	</xsl:template>
	<!-- empty-line -->
	<xsl:template match="empty-line">
		<br/>
	</xsl:template>
	<!-- link -->
	<xsl:template match="a">
		<xsl:choose>
			<xsl:when test="(@type) = 'note'">
				<xsl:element name="a">
					<xsl:attribute name="href"><xsl:value-of select="$FileName"/>_<xsl:value-of select="$TotalPages"/>.html<xsl:value-of select="@xlink:href"/></xsl:attribute>
					<sup>
						<xsl:apply-templates/>
					</sup>
				</xsl:element>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<!-- annotation -->
	<xsl:template name="annotation">
		<xsl:if test="@id">
			<xsl:element name="a">
				<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
			</xsl:element>
		</xsl:if>
		<h3>Annotation</h3>
		<xsl:apply-templates/>
	</xsl:template>
	<!-- epigraph -->
	<xsl:template match="epigraph">
		<blockquote class="epigraph">
			<xsl:if test="@id">
				<xsl:element name="a">
					<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
				</xsl:element>
			</xsl:if>
			<xsl:apply-templates/>
		</blockquote>
	</xsl:template>
	<!-- epigraph/text-author -->
	<xsl:template match="epigraph/text-author">
		<blockquote>
			<i><xsl:apply-templates/></i>
		</blockquote>
	</xsl:template>
	<!-- cite -->
	<xsl:template match="cite">
		...<blockquote><i>
		<xsl:if test="@id">
			<xsl:element name="a">
				<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
			</xsl:element>
		</xsl:if>
		<xsl:apply-templates/>
		</i></blockquote>
	</xsl:template>
	<!-- cite/text-author -->
	<xsl:template name="text-author">
		<br/>
		<i>	<xsl:apply-templates/></i>
	</xsl:template>
	<!-- date -->
	<xsl:template match="date">
		<xsl:choose>
			<xsl:when test="not(@value)">
				&#160;&#160;&#160;<xsl:apply-templates/>
				<br/>
			</xsl:when>
			<xsl:otherwise>
				&#160;&#160;&#160;<xsl:value-of select="@value"/>
				<br/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<!-- poem -->
	<xsl:template match="poem">
		<blockquote>
			<xsl:if test="@id">
				<xsl:element name="a">
					<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
				</xsl:element>
			</xsl:if>
			<xsl:apply-templates/>
		</blockquote>
	</xsl:template>
	<!-- poem/title -->
<!--	<xsl:template match="poem/title">
			<h6><xsl:apply-templates/></h6>
		</blockquote>
	</xsl:template> -->
	<!-- stanza -->
	<xsl:template match="stanza">
		<br/>
		<xsl:apply-templates/>
		<br/>
	</xsl:template>
	<!-- v -->
	<xsl:template match="v">
		<xsl:if test="@id">
			<xsl:element name="a">
				<xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
			</xsl:element>
		</xsl:if>
		<xsl:apply-templates/><br/>
	</xsl:template>
	<!-- image -->
	<xsl:template match="image">
		<div align="center">
			<img border="1">
				<xsl:choose>
					<xsl:when test="starts-with(@xlink:href,'#')">
						<xsl:attribute name="src"><xsl:value-of select="substring-after(@xlink:href,'#')"/></xsl:attribute>
					</xsl:when>
					<xsl:otherwise>
						<xsl:attribute name="src"><xsl:value-of select="@xlink:href"/></xsl:attribute>
					</xsl:otherwise>
				</xsl:choose>
			</img>
		</div>
	</xsl:template>
	<xsl:template match="title">
		<xsl:choose>
			<xsl:when test="@deepness &gt; 5"><h6><a name="@number"></a><xsl:apply-templates/></h6></xsl:when>
			<xsl:otherwise><xsl:element name="h{@deepness+1}"><a name="@number"></a><xsl:apply-templates/></xsl:element></xsl:otherwise>
		</xsl:choose>
		
	</xsl:template>
	<xsl:template name="for">
		<xsl:param name="i" select="0"/>
		<xsl:param name="n" select="$TotalPages"/>
			<xsl:if test="$i &lt;= $n">
			<xsl:choose>
				<xsl:when test="$i = $PageN">
					<strong>
						<xsl:choose>
							<xsl:when test="$i != 0"><xsl:value-of select="$i"/></xsl:when>
							<xsl:otherwise>Содержание</xsl:otherwise>
						</xsl:choose>
					</strong>
				</xsl:when>
				<xsl:otherwise>
					<xsl:element name="a">
						<xsl:attribute name="href"><xsl:value-of select="$FileName"/>_<xsl:value-of select="$i"/>.html</xsl:attribute>
						<xsl:attribute name="title">Перейти на страницу <xsl:value-of select="$i"/></xsl:attribute>
						<xsl:choose>
							<xsl:when test="$i != 0"><xsl:value-of select="$i"/></xsl:when>
							<xsl:otherwise>Содержание</xsl:otherwise>
						</xsl:choose>
					</xsl:element>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:if test="$i &lt; $n"> &#160;|&#160; </xsl:if>
			<xsl:call-template name="for">
				<xsl:with-param name="i" select="$i + 1"/>
				<xsl:with-param name="n" select="$n"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
</xsl:stylesheet>